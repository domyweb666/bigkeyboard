# 改版（例如 1.2.1）的文案寫進 App Store Connect：寫「此版本的新功能」、審查備註，描述有改也一起寫。
# 在 GitHub Actions 跑（.github/workflows/asc-release.yml，推 asc-release 分支觸發），金鑰用 repo secrets。
# 文字從 .aso/<版本>-送審稿.md 讀：第 1 個程式碼區塊＝繁中新功能說明、第 2 個＝英文（英國）、第 3 個＝審查備註要加在最前面的段落。
# 後台沒有這個版本就建草稿（Apple 會沿用上一版的描述、關鍵字、截圖）；缺語系時照上一版補。
# 描述從定稿讀（繁中 05-素材文案.md 第 1 個程式碼區塊、英文 04-英國英文.md 第 4 個），跟後台不一樣才寫；
# 一次改超過 DESCRIPTION_MAX_CHANGED 行就停（定稿跟後台差太多，先查原因）。
# 不動名稱、副標、關鍵字、截圖。寫完重讀比對，有一欄不對就失敗。
# 預設不選 build、不送審。要送審：python -I .aso/asc_release.py --submit <build 號>
# （文案比對全對、那個 build 處理完成，才會選上去並提交審查；送出去就收不回來，只能在後台撤回）
# 本機只想看會寫什麼：python -I .aso/asc_release.py --dry-run（不連 Apple）
import os
import re
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).parent
API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "org.domyweb.bigkeyboard"
VERSION = "1.2.1"
# 後台如果還留著這些版本號的草稿，直接改名成 VERSION（1.2 那次用過：1.1.1 取消，併進 1.2）
RENAME_FROM = set()
# 上一版的審查備註最前面如果是這些版本加的段落，先拿掉再加這次的（上限 4000 字，每版都往前加會放不下）
DROP_NOTES_FROM = ("1.2",)
# 描述一次最多改幾行（新舊各算一行）
DESCRIPTION_MAX_CHANGED = 4
LOCALES = ("zh-Hant", "en-GB")
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
# 新語系要從上一版帶過來的欄位
COPY_FIELDS = ("description", "keywords", "promotionalText", "supportUrl", "marketingUrl")
# 審查聯絡資料：從上一版帶過來，不印到 log
REVIEW_FIELDS = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail",
                 "demoAccountName", "demoAccountPassword", "demoAccountRequired")


def blocks(name):
    text = (HERE / name).read_text(encoding="utf-8")
    return [x.strip() for lang, x in re.findall(r"```(\w*)\n(.*?)```", text, re.S) if not lang]


def load_descriptions():
    desc = {"zh-Hant": blocks("05-素材文案.md")[0], "en-GB": blocks("04-英國英文.md")[3]}
    for loc, v in desc.items():
        if len(v) > 4000:
            sys.exit(f"{loc} 描述超過 4000 字")
    return desc


def changed_lines(current, target):
    """後台現在的描述跟定稿差在哪幾行（- 是後台的，+ 是定稿的）"""
    import difflib
    return [line for line in difflib.unified_diff(current.splitlines(), target.splitlines(), lineterm="", n=0)
            if line[:1] in "+-" and line[:3] not in ("+++", "---")]


def write_descriptions(asc, loc, descriptions):
    for lc, text in descriptions.items():
        cur = loc[lc]
        diff = changed_lines(cur["attributes"].get("description") or "", text)
        if not diff:
            print(f"  {lc} 描述：已經一樣")
            continue
        for line in diff:
            print(f"    {line[:160]}")
        if len(diff) > DESCRIPTION_MAX_CHANGED:
            sys.exit(f"{lc} 描述跟後台差了 {len(diff)} 行，超過 {DESCRIPTION_MAX_CHANGED} 行。停，先查定稿跟後台為什麼差這麼多。")
        asc.call("PATCH", f"/appStoreVersionLocalizations/{cur['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": cur["id"], "attributes": {"description": text}}})
        print(f"  {lc} 描述：寫入（改了 {len(diff)} 行）")


def load_text():
    b = blocks(f"{VERSION}-送審稿.md")
    copy = {"zh-Hant": b[0], "en-GB": b[1]}
    for loc, v in copy.items():
        if len(v) > 4000:
            sys.exit(f"{loc} 新功能說明超過 4000 字")
    return copy, b[2]


class ASC:
    def __init__(self):
        import jwt
        import requests
        self.r = requests
        tok = jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()), "exp": int(time.time()) + 1200,
             "aud": "appstoreconnect-v1"},
            os.environ["ASC_PRIVATE_KEY"], algorithm="ES256",
            headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
        )
        self.h = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}

    def call(self, method, path, body=None):
        res = self.r.request(method, API + path, headers=self.h, json=body)
        if res.status_code >= 400:
            print(f"!! {method} {path} → {res.status_code}\n{res.text[:2000]}")
            sys.exit(1)
        return res.json() if res.text else {}


def vstate(v):
    a = v["attributes"]
    return a.get("appVersionState") or a.get("appStoreState")


def versions(asc, app_id):
    vs = asc.call("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    for v in vs:
        print(f"  版本 {v['attributes']['versionString']}：{vstate(v)}")
    return vs


def find_or_create(asc, app_id, vs):
    mine = [v for v in vs if v["attributes"]["versionString"] == VERSION]
    if mine:
        if vstate(mine[0]) not in EDITABLE:
            sys.exit(f"{VERSION} 現在是 {vstate(mine[0])}，不能改。停。")
        print(f"  後台已有 {VERSION} 草稿，沿用")
        return mine[0]["id"]
    editing = [v for v in vs if vstate(v) in EDITABLE]
    if editing:
        old = editing[0]
        name = old["attributes"]["versionString"]
        if name not in RENAME_FROM:
            sys.exit(f"後台已經有準備中的版本 {name}，不是 {VERSION}。停，請多米確認。")
        print(f"  後台準備中的版本是 {name}，改名成 {VERSION}")
        asc.call("PATCH", f"/appStoreVersions/{old['id']}", {"data": {
            "type": "appStoreVersions", "id": old["id"], "attributes": {"versionString": VERSION}}})
        return old["id"]
    print(f"  後台沒有 {VERSION}，建一個草稿")
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": VERSION},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    return asc.call("POST", "/appStoreVersions", body)["data"]["id"]


def previous_version(vs):
    """上一個上架過的版本（建立時間最新、不是這次的版本）"""
    live = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE"}
    for v in sorted(vs, key=lambda x: x["attributes"].get("createdDate") or "", reverse=True):
        if v["attributes"]["versionString"] != VERSION and vstate(v) in live:
            return v
    sys.exit("找不到上一個上架的版本。停。")


def localizations(asc, version_id):
    return {x["attributes"]["locale"]: x for x in
            asc.call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]}


def review_detail(asc, version_id):
    return asc.call("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")


def main():
    copy, note = load_text()
    descriptions = load_descriptions()
    if "--dry-run" in sys.argv:
        for loc, v in copy.items():
            print(f"── {loc} 新功能說明（{len(v)} 字）\n{v}\n")
            print(f"── {loc} 描述（{len(descriptions[loc])} 字，跟後台不一樣才寫）\n")
        print(f"── 審查備註最前面加（{len(note)} 字）\n{note}")
        return

    asc = ASC()
    app = asc.call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    print(f"App：{app['attributes']['name']}（{app['id']}）")
    vs = versions(asc, app["id"])
    prev = previous_version(vs)
    print(f"  上一版：{prev['attributes']['versionString']}")
    version_id = find_or_create(asc, app["id"], vs)

    # 語系：新建的版本 Apple 通常會沿用上一版，缺的話照上一版補
    prev_loc = localizations(asc, prev["id"])
    loc = localizations(asc, version_id)
    print("  目前的語系：", sorted(loc))
    for lc in LOCALES:
        if lc in loc:
            continue
        src = prev_loc.get(lc, {}).get("attributes") or {}
        attrs = {"locale": lc, **{k: src[k] for k in COPY_FIELDS if src.get(k)}}
        asc.call("POST", "/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        print(f"  補上語系 {lc}（照上一版的描述、關鍵字、網址）")
    loc = localizations(asc, version_id)

    for lc, text in copy.items():
        cur = loc[lc]
        if cur["attributes"].get("whatsNew") != text:
            asc.call("PATCH", f"/appStoreVersionLocalizations/{cur['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": cur["id"], "attributes": {"whatsNew": text}}})
            print(f"  {lc} 新功能說明：寫入")
        else:
            print(f"  {lc} 新功能說明：已經一樣")
    write_descriptions(asc, loc, descriptions)

    # 審查備註：上一個上架版本的備註，最前面加這次的段落。
    # 一律從上架的那一版組，不從草稿現有的備註接：草稿可能還留著別的版本加的段落（例如取消掉的 1.1.1）
    detail = review_detail(asc, version_id)
    old = review_detail(asc, prev["id"])
    old_notes = ((old or {}).get("attributes") or {}).get("notes") or ""
    for dropped in DROP_NOTES_FROM:
        paragraph = blocks(f"{dropped}-送審稿.md")[2]
        if old_notes.startswith(paragraph):
            old_notes = old_notes[len(paragraph):].lstrip()
            print(f"  審查備註：拿掉 {dropped} 加的那段（{len(paragraph)} 字）")
    target = old_notes if old_notes.startswith(note) else (note + "\n\n" + old_notes).strip()
    print(f"  審查備註：這次的段落 {len(note)} 字＋上一版的備註 {len(old_notes)} 字＝{len(target)} 字（上限 4000）")
    if len(target) > 4000:
        sys.exit(f"審查備註超過 4000 字，多了 {len(target) - 4000} 字。把送審稿第二節寫短再跑。")
    if detail:
        if detail["attributes"].get("notes") != target:
            asc.call("PATCH", f"/appStoreReviewDetails/{detail['id']}", {"data": {
                "type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": target}}})
            print("  審查備註：最前面加上這次的段落")
        else:
            print("  審查備註：已經加過")
    else:
        src = (old or {}).get("attributes") or {}
        attrs = {k: src[k] for k in REVIEW_FIELDS if src.get(k) is not None}
        attrs["notes"] = target
        asc.call("POST", "/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
        print(f"  審查資訊：照上一版建一份（聯絡資料 {len(attrs) - 1} 欄，不印出），備註最前面加上這次的段落")

    print("\n寫完，重新讀一次比對：")
    loc = localizations(asc, version_id)
    bad = 0
    for lc, text in copy.items():
        ok = loc.get(lc, {}).get("attributes", {}).get("whatsNew") == text
        bad += not ok
        print(f"  {'OK ' if ok else '不符'} {lc} 新功能說明（{len(text)} 字）")
        a = loc.get(lc, {}).get("attributes", {})
        ok = a.get("description") == descriptions[lc]
        bad += not ok
        print(f"  {'OK ' if ok else '不符'} {lc} 描述（{len(descriptions[lc])} 字）")
        print(f"      關鍵字 {len(a.get('keywords') or '')} 字｜支援網址 {a.get('supportUrl')}")
    d = (review_detail(asc, version_id) or {}).get("attributes") or {}
    notes = d.get("notes") or ""
    ok = notes.startswith(note)
    bad += not ok
    print(f"  {'OK ' if ok else '不符'} 審查備註最前面是這次的段落（備註共 {len(notes)} 字）")
    print(f"  審查聯絡資料：{'有' if d.get('contactEmail') else '沒有，要到後台補'}")
    if bad:
        sys.exit(f"{bad} 項對不上")
    if "--submit" not in sys.argv:
        print(f"\n{VERSION} 草稿文案寫好了。build 還沒選、還沒送審。")
        return
    submit(asc, app["id"], version_id, sys.argv[sys.argv.index("--submit") + 1])


def submit(asc, app_id, version_id, build_number):
    """選 build、提交審查。文案比對全對才會走到這裡"""
    builds = asc.call("GET", f"/builds?filter[app]={app_id}&filter[version]={build_number}"
                             f"&filter[preReleaseVersion.version]={VERSION}&limit=5")["data"]
    if not builds:
        sys.exit(f"找不到 {VERSION} 的 build {build_number}（還沒上傳，或版本號不是 {VERSION}）。停。")
    build = builds[0]
    state = build["attributes"].get("processingState")
    if state != "VALID":
        sys.exit(f"build {build_number} 現在是 {state}，還不能送。等 Apple 處理完再跑一次。")
    asc.call("PATCH", f"/appStoreVersions/{version_id}/relationships/build",
             {"data": {"type": "builds", "id": build["id"]}})
    print(f"  已選 build {build_number}")

    # 有還沒送出的提交單就沿用，沒有才建
    opened = asc.call("GET", f"/reviewSubmissions?filter[app]={app_id}&filter[platform]=IOS"
                             "&filter[state]=READY_FOR_REVIEW")["data"]
    if opened:
        sid = opened[0]["id"]
        print("  沿用後台還沒送出的提交單")
    else:
        sid = asc.call("POST", "/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]["id"]
    items = asc.call("GET", f"/reviewSubmissions/{sid}/items")["data"]
    if not items:
        asc.call("POST", "/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    asc.call("PATCH", f"/reviewSubmissions/{sid}", {"data": {
        "type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
    after = asc.call("GET", f"/reviewSubmissions/{sid}")["data"]["attributes"].get("state")
    print(f"\n{VERSION}（build {build_number}）已提交審查，提交單狀態：{after}")


if __name__ == "__main__":
    main()
