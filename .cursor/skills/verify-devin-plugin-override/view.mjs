export const title = "Devin 型をプラグインで上書きする";

export const colors = {
  builtin: "blue",
  full: "teal",
  keys: "orange",
  auto: "purple",
};

export const group = (v) => {
  if (v.place === "none" || v.pin !== "held") return "builtin";
  if (v.place === "full") return "full";
  if (v.place === "keys") return "keys";
  return "auto";
};

export const state = (v) => {
  const core = v.core === "spawnable" ? "本体は spawn 可" : "本体は spawn 不可";
  if (v.place === "none") return `プラグイン無し（${core}）`;
  if (v.pin === "open") return `未信頼（${core}）`;
  if (v.pin === "moved") return `パスが一致しない（${core}）`;
  if (v.place === "full") return "完全な上書き。spawn 可、配信は手動";
  if (v.place === "keys") return "3キーだけの上書き";
  return "自動配信を宣言。spawn 可、monitor は通る";
};

const labels = {
  PlaceFull: "完全な type.conf を置く",
  PlaceKeys: "spawn の3キーだけ置く",
  PlaceAuto: "monitor を許す type.conf を置く",
  Remove: "プラグインを外す",
  Trust: "そのパスを信頼する",
  Move: "信頼したディレクトリを動かす",
  Untrust: "信頼を外す",
  CoreUpdate: "本体が devin を spawn 可にする",
  AskSpawn: "spawn を頼む",
  AskPush: "配信を monitor にする",
};

export const step = (action) => labels[action] ?? action;
