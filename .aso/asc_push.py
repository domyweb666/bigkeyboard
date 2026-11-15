# 把 .aso 裡的定稿文案寫進 App Store Connect 的 1.1 版本（繁中＋英文（英國））。
# 在 GitHub Actions 跑（.github/workflows/asc-metadata.yml），金鑰用 repo secrets。
# 只改文字：名稱、副標、描述、關鍵字、推廣文字、此版本的新功能。不動截圖、不選 build、不送審。
# 後台沒有 1.1 就建一個 1.1 草稿；架上的 1.0 不動。寫完再讀一次逐欄比對，有一欄對不上就失敗。
# 本機只想看會推什麼：python -I .aso/asc_push.py --dry-run（不連 Apple）
import os
import re
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).parent
API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "org.domyweb.bigkeyboard"
VERSION = "1.1"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}


def blocks(name):
    text = (HERE / name).read_text(encoding="utf-8")
    return [b.strip() for lang, b in re.findall(r"```(\w*)\n(.*?)```", text, re.S) if not lang]


def load_copy():
    meta = (HERE / "04-metadata.md").read_text(encoding="utf-8")
    zh = blocks("05-素材文案.md")  # 0 描述 1 推廣文字 2 新功能說明
    uk = blocks("04-英國英文.md")  # 0 名稱 1 副標 2 關鍵字 3 描述 4 推廣文字 5 新功能說明
    copy = {
        "zh-Hant": {
            "name": re.search(r"\| 名稱 \| (豆鍵：大字注音鍵盤)", meta).group(1),
            "subtitle": re.search(r"\| 副標 \| (.+?)（S2）", meta).group(1),
            "keywords": blocks("04-metadata.md")[0],
            "description": zh[0],
            "promotionalText": zh[1],
            "whatsNew": zh[2],
        },
        "en-GB": {
            "name": uk[0],
            "subtitle": uk[1],
            "keywords": uk[2],
            "description": uk[3],
            "promotionalText": uk[4],
            "whatsNew": uk[5],
        },
    }
    limits = {"name": 30, "subtitle": 30, "keywords": 100, "description": 4000,
              "promotionalText": 170, "whatsNew": 4000}
    for loc, fields in copy.items():
        for k, v in fields.items():
            if len(v) > limits[k]:
                sys.exit(f"{loc} {k} 超過字數：{len(v)}/{limits[k]}")
    return copy


INFO_FIELDS = ("name", "subtitle")
VERSION_FIELDS = ("description", "keywords", "promotionalText", "whatsNew")


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


def short(v):
    v = (v or "").replace("\n", "⏎")
    return v if len(v) <= 60 else v[:57] + "⋯"


def show_diff(label, current, target):
    print(f"\n── {label}")
    for k, v in target.items():
        cur = current.get(k)
        mark = "不變" if cur == v else "要改"
        print(f"  [{mark}] {k}\n      現在：{short(cur)}\n      新的：{short(v)}")


def vstate(v):
    a = v["attributes"]
    return a.get("appVersionState") or a.get("appStoreState")


def find_version(asc, app_id):
    vs = asc.call("GET", f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    for v in vs:
        print(f"  版本 {v['attributes']['versionString']}：{vstate(v)}")
    mine = [v for v in vs if v["attributes"]["versionString"] == VERSION]
    if mine:
        state = vstate(mine[0])
        if state not in EDITABLE:
            sys.exit(f"1.1 現在是 {state}，不能改文案。停。")
        return mine[0]["id"]
    editing = [v for v in vs if vstate(v) in EDITABLE]
    if editing:
        sys.exit(f"後台已經有一個準備中的版本 {editing[0]['attributes']['versionString']}，不是 1.1。停，請多米確認。")
    print(f"  後台沒有 {VERSION}，建一個草稿")
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": VERSION},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    return asc.call("POST", "/appStoreVersions", body)["data"]["id"]


def editable_app_info(asc, app_id):
    infos = asc.call("GET", f"/apps/{app_id}/appInfos")["data"]
    for i in infos:
        a = i["attributes"]
        print(f"  App 資訊 {i['id'][:8]}：{a.get('state') or a.get('appStoreState')}")
    live = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}
    cands = [i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in live]
    if not cands:
        sys.exit("找不到可以編輯的 App 資訊（名稱、副標放在這裡）。停。")
    return cands[0]["id"]


def upsert(asc, kind, parent_rel, parent_type, parent_id, existing, locale, attrs, extra_new=None):
    if locale in existing:
        cur = existing[locale]
        diff = {k: v for k, v in attrs.items() if cur["attributes"].get(k) != v}
        if diff:
            asc.call("PATCH", f"/{kind}/{cur['id']}",
                     {"data": {"type": kind, "id": cur["id"], "attributes": diff}})
        return
    new_attrs = {"locale": locale, **(extra_new or {}), **attrs}
    asc.call("POST", f"/{kind}", {"data": {
        "type": kind, "attributes": new_attrs,
        "relationships": {parent_rel: {"data": {"type": parent_type, "id": parent_id}}}}})


def main():
    copy = load_copy()
    if "--dry-run" in sys.argv:
        for loc, f in copy.items():
            show_diff(f"{loc}（本機，不連 Apple）", {}, f)
        return

    asc = ASC()
    app = asc.call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    print(f"App：{app['attributes']['name']}（{app['id']}）主要語系 {app['attributes'].get('primaryLocale')}")
    version_id = find_version(asc, app["id"])
    info_id = editable_app_info(asc, app["id"])

    def read():
        vl = {x["attributes"]["locale"]: x for x in
              asc.call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]}
        il = {x["attributes"]["locale"]: x for x in
              asc.call("GET", f"/appInfos/{info_id}/appInfoLocalizations")["data"]}
        return vl, il

    vloc, iloc = read()
    print("  目前的語系：版本", sorted(vloc), "／App 資訊", sorted(iloc))
    for loc, f in copy.items():
        cur = {**(iloc.get(loc, {}).get("attributes") or {}), **(vloc.get(loc, {}).get("attributes") or {})}
        show_diff(f"{loc}（後台現在 vs 定稿）", cur, f)

    zh_v = vloc.get("zh-Hant", {}).get("attributes", {})
    zh_i = iloc.get("zh-Hant", {}).get("attributes", {})
    for loc, f in copy.items():
        upsert(asc, "appInfoLocalizations", "appInfo", "appInfos", info_id, iloc, loc,
               {k: f[k] for k in INFO_FIELDS},
               {"privacyPolicyUrl": zh_i.get("privacyPolicyUrl")} if zh_i.get("privacyPolicyUrl") else None)
        upsert(asc, "appStoreVersionLocalizations", "appStoreVersion", "appStoreVersions", version_id, vloc, loc,
               {k: f[k] for k in VERSION_FIELDS},
               {k: zh_v[k] for k in ("supportUrl", "marketingUrl") if zh_v.get(k)})

    print("\n寫完，重新讀一次比對：")
    vloc, iloc = read()
    bad = 0
    for loc, f in copy.items():
        cur = {**(iloc.get(loc, {}).get("attributes") or {}), **(vloc.get(loc, {}).get("attributes") or {})}
        for k, v in f.items():
            ok = cur.get(k) == v
            bad += not ok
            print(f"  {'OK ' if ok else '不符'} {loc} {k}（{len(v)} 字）")
    if bad:
        sys.exit(f"{bad} 欄跟定稿對不上")
    print("\n全部欄位跟定稿一字不差。還沒送審，截圖沒動。")


if __name__ == "__main__":
    main()
