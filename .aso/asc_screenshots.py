# 把 .aso/截圖/out 的上架圖換進 App Store Connect 的 1.1 版本（繁中；英文（英國）有自己的截圖組才一起換）。
# 在 GitHub Actions 跑（.github/workflows/asc-screenshots.yml）。
# 順序：清空那一組（一組最多 10 張）、傳 9 張、等 Apple 處理完成、排順序、讀回來比對。重跑是安全的。
# 不動文字、不選 build、不送審。
import hashlib
import os
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).parent
API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "org.domyweb.bigkeyboard"
VERSION = "1.1"
# 截圖組類型 → 用哪一組圖
TYPE_DIR = {"APP_IPHONE_67": "6.9", "APP_IPHONE_61": "6.3"}
PRIMARY = "zh-Hant"


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


def files_for(label):
    files = sorted((HERE / "截圖" / "out" / label).glob("*.jpg"))
    if len(files) != 9:
        sys.exit(f"{label} 應該有 9 張，找到 {len(files)} 張")
    return files


def upload(asc, set_id, path):
    data = path.read_bytes()
    res = asc.call("POST", "/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for op in res["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        up = asc.r.request(op["method"], op["url"], headers=hdr, data=chunk)
        if up.status_code >= 400:
            sys.exit(f"!! 上傳 {path.name} 失敗：{up.status_code} {up.text[:500]}")
    asc.call("PATCH", f"/appScreenshots/{res['id']}", {"data": {
        "type": "appScreenshots", "id": res["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return res["id"]


def wait_done(asc, ids):
    for _ in range(60):
        states = {}
        for i in ids:
            a = asc.call("GET", f"/appScreenshots/{i}")["data"]["attributes"]
            st = (a.get("assetDeliveryState") or {})
            states[i] = st.get("state")
            if st.get("state") == "FAILED":
                print(f"!! Apple 處理失敗：{a.get('fileName')} {st.get('errors')}")
                return False
        if all(s == "COMPLETE" for s in states.values()):
            return True
        time.sleep(5)
    print("!! 等了 5 分鐘還沒處理完", states)
    return False


def replace_set(asc, s):
    stype = s["attributes"]["screenshotDisplayType"]
    label = TYPE_DIR[stype]
    # 一組最多 10 張，舊 6＋新 9 放不下，所以先清空再傳（1.1 是草稿，暫時空著不影響架上的 1.0）
    old = [x["id"] for x in asc.call("GET", f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]]
    print(f"  {stype}（{label}）：清掉舊的 {len(old)} 張，傳新的 9 張")
    for i in old:
        asc.call("DELETE", f"/appScreenshots/{i}")
    new = [upload(asc, s["id"], f) for f in files_for(label)]
    if not wait_done(asc, new):
        sys.exit("新截圖沒處理成功。這組現在不完整，修好後重跑一次就會清掉重傳。停。")
    asc.call("PATCH", f"/appScreenshotSets/{s['id']}/relationships/appScreenshots",
             {"data": [{"type": "appScreenshots", "id": i} for i in new]})
    return new


def main():
    asc = ASC()
    app = asc.call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    vs = asc.call("GET", f"/apps/{app['id']}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    v = [x for x in vs if x["attributes"]["versionString"] == VERSION]
    if not v:
        sys.exit("後台沒有 1.1。停。")
    state = v[0]["attributes"].get("appVersionState") or v[0]["attributes"].get("appStoreState")
    print(f"1.1 狀態：{state}")
    if state not in {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}:
        sys.exit("1.1 現在不能改截圖。停。")
    locs = asc.call("GET", f"/appStoreVersions/{v[0]['id']}/appStoreVersionLocalizations")["data"]

    for loc in locs:
        code = loc["attributes"]["locale"]
        sets = asc.call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        print(f"\n── {code}：截圖組 {[s['attributes']['screenshotDisplayType'] for s in sets]}")
        if code == PRIMARY:
            have = {s["attributes"]["screenshotDisplayType"] for s in sets}
            for t in TYPE_DIR:
                if t not in have:
                    print(f"  建 {t} 截圖組")
                    sets.append(asc.call("POST", "/appScreenshotSets", {"data": {
                        "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": t},
                        "relationships": {"appStoreVersionLocalization": {"data": {
                            "type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"])
        elif not sets:
            print("  沒有自己的截圖組，會沿用繁中的，不動")
        for s in sets:
            t = s["attributes"]["screenshotDisplayType"]
            if t not in TYPE_DIR:
                print(f"  {t}：沒有這個尺寸的圖，不動")
                continue
            replace_set(asc, s)

    print("\n讀回來確認：")
    bad = 0
    for loc in locs:
        for s in asc.call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
            t = s["attributes"]["screenshotDisplayType"]
            shots = asc.call("GET", f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]
            names = [x["attributes"]["fileName"] for x in shots]
            want = [f.name for f in files_for(TYPE_DIR[t])] if t in TYPE_DIR else names
            ok = names == want
            bad += not ok
            print(f"  {'OK ' if ok else '不符'} {loc['attributes']['locale']} {t}：{len(names)} 張 {names}")
    if bad:
        sys.exit(f"{bad} 組順序或張數不對")
    print("\n截圖全部換好，順序對。還沒送審。")


if __name__ == "__main__":
    main()
