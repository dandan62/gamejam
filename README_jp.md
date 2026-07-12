# Deep Abiss

**Godot 4.6.2 / GDScript** で作った、人間2人＋CPU1体のホットシート形式・スコアアタック型ボードゲーム
（いわゆる push-your-luck＝欲張りすぎるとゼロになるタイプのゲーム）です。

プレイヤーは交互にダイスを振り、枝分かれした地下マップを奥へ進んでお宝を集めます。HPかライトが
尽きる前に、どこで引き返すかを自分で判断するのが肝です。お宝はスタート地点まで持ち帰って初めて
スコアとして確定します。途中で脱落したりライト切れになると、その時点で持っているお宝は全て失います。

ゲーム内容は**完全にデータ駆動**です。マップ／お宝／イベント／遺物はすべて `data/` 以下の
個別ファイルとして存在するので、コードを一切触らずに新しいコンテンツの追加や調整ができます。

## 必要環境・起動方法

- Godot **4.6.2**（`project.godot` の `config/features` で `4.6` + Forward Plus を指定、レンダリング
  方式は `gl_compatibility`）。
- エディタで `project.godot` を開いて実行するだけです。メインシーンは `Main.tscn` ですが、中身は
  ほぼ空の `Control` ノードに `scenes/Main.gd` がアタッチされているだけで、盤面・HUD・ダイス・
  ポップアップなどUI全体は `.tscn` 上のレイアウトではなく `_ready()` 内でコードから組み立てられます。
- ビルド手順や外部依存関係はありません。

## プロジェクト構成

```
deep_abiss/
  project.godot
  data/                        # ゲームコンテンツ全般 — 詳細は下記「コンテンツの作り方」参照
    maps/*.txt                 # マップレイアウト（テキスト形式。詳細は下記）
    treasures/tierN/*.tres
    events/tierN/*.tres
    relics/tierN/*.tres
  scenes/
    Main.gd                    # ルート。UIツリー全体を構築し、TurnManagerのシグナルを配線する
    Board.gd                   # マップのグラフと駒を描画し、マスのクリックを受け付ける
    ui/
      HUD.gd, SegmentGauge.gd  # プレイヤーごとのHP/ライト/行動力ゲージ＋所持お宝アイコン
      DiceUI.gd, Dice3D.gd     # ダイスを振るボタン＋3Dダイスの見た目＋ダイス下のマス種別凡例
      ActionPanel.gd           # 拾う/無視/捨てるの選択UI
      EventPopup.gd            # イベントの2択UI
      GameOverScreen.gd        # 最終順位表示
  scripts/
    autoload/
      GameManager.gd           # シングルトン。プレイヤー一覧・手番・ラウンド数・マップ/スポナー参照
      DataLoader.gd            # シングルトン。data/以下を全て読み込みキャッシュを作る
    core/
      TurnManager.gd           # ターン進行のステートマシン本体（下記参照）
      DiceRoller.gd            # 1D6ロール
      TierSelector.gd          # 深度→tierの帯域マッピング
      TreasureSpawner.gd       # ゲーム開始時、マスごとにお宝/遺物の中身を1回だけ抽選する
      StatIcons.gd             # HP/ライト/スコア等のバフ表示用ラベル＋アイコン文字列
      TileIcons.gd             # マス種別ごとの色・ラベル・説明。Boardとダイス下の凡例が共有
    map/
      MapGraph.gd              # MapDefinitionから前進/後退の隣接情報（ランタイムグラフ）を構築
      MapTextLoader.gd         # data/maps/*.txt を解析してMapDefinitionを作る
    data_models/                # 各コンテンツ種別に対応する素のResource（class_name付き）定義
      MapDefinition.gd, MapNodeDef.gd
      TreasureData.gd, EventData.gd, RelicData.gd
      EffectData.gd, BuffData.gd
    entities/
      PlayerState.gd           # 1プレイヤー分のHP/ライト/重量/所持お宝/ステータス
      CPUAI.gd                 # ヒューリスティックAI。方向選択・マスでの行動・イベント選択を判断
```

## ルール・基本ループ

デフォルト値：`HP = 3`、`Light = 5`、重量上限 `= 5`。いずれもバフで変動します。

1ターン（`TurnManager.gd`）の流れ：

1. **ダイスロール** — 1D6 ＋ 現在のバックパックの空き（重量上限 − 所持重量） ＋ `MOVE` バフ分の
   ボーナス＝このターンの移動力。お宝を多く持つほど、次のロールでの移動力は小さくなります。
2. **1マスずつ移動** — 移動力を使い切るか、行き先がなくなるまで1マスずつ進みます。**マスに止まる
   たびに**、前進（奥へ）・後退（手前へ）両方向の隣接マスをまとめて候補として提示します。つまり
   方向はターン開始時に一度決めるのではなく、**1マスごとに選び直せます**。候補が1つしかない場合
   でも**自動では進まず**、人間プレイヤーは必ず盤面上のハイライトされたマスをクリック（前進は白、
   後退は水色の光）、CPUは必ず `CPUAI.choose_path()` で明示的に判断します。
3. **止まったマスの解決**：
   - `EMPTY`（空マス） — 何も起きません。プロンプトを出さず（人間・CPUどちらの場合も）即座に
     解決されるので、テンポを損ないません。
   - `TREASURE`（お宝） — 拾う（重量上限内に収まる場合のみ）か無視。拾うとそのお宝のHPダメージと
     `WHILE_HELD`/`PERMANENT` バフが即座に適用されます。
   - `EVENT`（イベント） — 2択のプロンプトが出て、選んだ方の `EffectData` が適用されます。
   - `BRIDGE`（橋） — 通過したプレイヤーが「橋を破壊する」か「そのままにする」かを選べます。破壊
     すると、そのマスは以後**誰も**（自分自身も含めて）通れなくなります（`MapGraph.get_forward_ids`/
     `get_backward_ids` の候補から除外されるだけの実装）。壊さなければ、次にそこを通る誰かが改めて
     同じ選択をできます。
   - `RELIC`（遺物） — スコアの無いお宝のように振る舞います。拾う（重量上限内に収まる場合のみ）か
     無視。拾うとその場でバフが永続付与され、`carried_relics` に入って重量を占有し続けます。
     `carried_treasures` と違い、帰還時のスコア確定でも脱落時でも一切クリアされません。
   - 既に取得済みの `TREASURE`/`RELIC` マスは `EMPTY` と同じ扱いになります。
4. **帰還** — 後退の結果スタート地点に到達すると、所持お宝の価値が `banked_score` に加算され、
   ライトが全回復し、ステータスが `RETURNED` になります。これは**引退ではありません**（詳細は下記）。
5. **ターン終了時** — 今戻ってきたばかりのターンでなければ、ライトが1減少します（`LIGHT` バフで
   軽減）。この結果HPまたはライトが `0` 以下になった場合、その時点で持っている（未帰還の）お宝を
   全て失い、ステータスが `ELIMINATED`（脱落）になります。

**帰還してもそのプレイヤーのゲームは終わりません。** `RETURNED` のプレイヤーも手番の順番に含まれ
続け、次に自分の手番が来た瞬間にステータスが `ACTIVE` に戻り、スタート地点からまた潜行を始めます
（ライトは全回復済み、それまでに確定させたスコアはそのまま保持されます）。手番からスキップされる
のは `ELIMINATED` のプレイヤーだけです。

**ゲーム終了条件**は次のいずれかです：
- ラウンド上限（`TurnManager.MAX_ROUNDS = 8`）を超えた — この時点でまだ `ACTIVE`（潜行中）の
  プレイヤーは強制的に脱落扱いとなり（未帰還のお宝を失う）、ゲームがきれいに終了する。
- 全プレイヤーが `ELIMINATED`（脱落）になった。

最終順位は `banked_score` の降順です（`GameManager.get_ranking()`）。

## アーキテクチャ

- **`GameManager`**（オートロード） — プレイヤー一覧、現在の手番インデックス、ラウンド数、
  `MapGraph`、`TreasureSpawner` を保持します。ターン進行ロジック自体は持たず、
  `advance_to_next_player()` は単に「脱落していない次のプレイヤー」へ手番を回し、全員が1巡したら
  `round_number` を進めるだけです。
- **`DataLoader`**（オートロード） — 起動時に `data/treasures`、`data/events`、`data/relics` を
  再帰的に走査し、見つけた `.tres` を全て `*_by_tier`（イベント/遺物は `*_by_id` も）の辞書に
  読み込みます。`data/maps/*.txt` も読み込みますが、こちらは**再帰的ではない**ため、マップファイル
  はサブフォルダではなく直下に置く必要があります。
- **`TurnManager`** は `Main` 配下の `Node` で、ターンの状態を持つのはここだけです
  （`State` enum: `IDLE, WAITING_ROLL, WAITING_STEP, WAITING_TILE_ACTION, WAITING_EVENT_CHOICE,
  GAME_OVER`）。観測可能な出来事は全てシグナルとして発行します（`dice_rolled`、
  `movement_changed`、`path_choices_ready`、`player_moved`、`player_returned`、
  `tile_action_needed`、`event_choice_needed`、`player_eliminated`、`turn_ended`、`game_over` など）。
  `Main.gd` はそれを受け取ってUIを更新するだけで、ゲームロジック自体は持ちません。人間の手番では
  UI側からの `roll_dice()` / `choose_path()` / `choose_tile_action()` / `choose_event()` 呼び出しを
  待ち、CPUの手番では各ステートに入った直後にこれらの関数を自分で呼び出します。
- **`MapGraph`** は `MapDefinition` の（フラットな）ノード一覧から前進/後退の隣接情報を構築します
  （後退側のエッジは、全ノードの `forward_connections` から自動的に逆算されます）。破壊済みの
  `BRIDGE` マスも保持しており（`break_bridge`/`is_bridge_broken`）、`get_forward_ids`/
  `get_backward_ids` の結果からは常に除外されるため、破壊済みの橋はどのマスからも到達不能になります。
- **`TreasureSpawner`** は、ゲーム開始時に全ての `TREASURE`/`RELIC` マスの中身を1回だけ抽選します
  （`TierSelector.pick_tier(depth)` でtierを決め、そのtierのプールからアイテムをランダムに選び、
  お宝の場合はさらに `min_value`/`max_value` の範囲で価値をロールします）。一度誰かが取得すると、
  そのマスはゲーム終了までずっと空マス扱いになります。
- **`CPUAI`** は状態を持たない単純なヒューリスティックです。前進先が無い場合、ライトが少ない
  （`<= 2`）状態で何か持っている場合、あるいは3個以上お宝を持っている場合は撤退を選びます。それ
  以外は前進候補の中で最も良さそうなマス（`TREASURE` > `RELIC` > `EVENT` > `EMPTY` = `BRIDGE` の
  順）へ進みます。マスでの行動もシンプルです（遺物もお宝も重量が収まる時だけ拾う、
  イベントはHP/ライト/スコアの増減からスコアリングして選択、橋は2個以上お宝を持っていれば
  追ってくる他プレイヤーを妨害するため破壊し、そうでなければそのままにする）。

## マップの作り方（`data/maps/*.txt`）

`MapTextLoader.gd` が解析します。ファイルの先頭行が`#`で始まる場合、それはマス行ではなく
**オプション行**として扱われ、深度の解析が始まる前に消費されます（スペース区切りの
`キー=値` トークン）。現在サポートしているキーは1つだけです：

| オプション | 効果 |
|---|---|
| `persist_tiles=true` | このマップの`TREASURE`/`RELIC`マスは取得しても消えなくなり、何度でも拾えるようになります。オプション行を省略する（あるいは`false`のまま）と、従来通り一度取得したら`EMPTY`扱いになります。 |

例えば、`#persist_tiles=true` の行から始めて、その後に通常のマス行・接続行を続けます。

オプション行の後（あれば）は、**マス行**と**接続行**を交互に並べたもので、
最初と最後は必ずマス行になります（1組が1深度に対応）。

| マスの文字 | 意味 |
|---|---|
| `S` | スタート（マップに1つだけ） |
| `n` | 何もない |
| `t` | お宝 |
| `e` | イベント |
| `h` | 橋 |
| `r` | 遺物 |
| `.` | その深度・そのレーンにはマスなし |

マス行の1文字が1レーンに対応し、レーン数は深度ごとに変えて構いません（`.` で歯抜けにできます）。
1ノードからの分岐数は少なめに保つのが想定（データモデル側のコメントには「最大5本まで」とあります
が、コード上で強制されているわけではありません）。

**接続行**は、ある深度のレーンが次の深度のどのレーンへ繋がるかを表します：
- **空行** → 自動接続：各レーンは次の深度の同じレーン番号とその両隣（`lane-1, lane, lane+1`）の
  うち実在するものへ繋がります。
- **空でない行** → 手動接続：スペース区切りで `元レーン:先レーン,先レーン,...` の形式を列挙します。
  例えば `0:0,1,2,3,4` は「レーン0を次の深度のレーン0〜4全てに繋ぐ」という意味です。

`data/maps/map_01.txt` の抜粋：

```
S
0:0,1,2,3,4
nnenn
0:0, 1:1, 2:2, 3:3, 4:4
nntrt
0:0, 1:0, 2:0, 3:0, 4:0
nn.n.

tnnht

ehhtt
```

読み方：深度0は `S` 1レーンのみで、手動接続により深度1の5レーン全て（`nnenn`）へ分岐します。
深度1は深度2（`nntrt`）へ1:1でまっすぐ接続。深度2は5レーン全てが深度3のレーン0（`nn.n.`。レーン2と
4は歯抜け）へ収束します。深度3以降は接続行が空行なので、深度4以降（`tnnht`、`ehhtt`、…）は自動
接続になります。

新しいマップを追加するには `data/maps/任意の名前.txt` を置くだけです。`DataLoader` はそのフォルダ
直下の `.txt` を全て自動で読み込みます。`GameManager.start_new_game(map_name)` はファイル名（拡張子
なし）でマップを引きます。引数なしで呼んだ場合（通常のゲーム開始時）は最初に読み込まれたマップが
使われるだけなので、複数のマップファイルを置く場合は、特定のマップを使いたければ名前を明示的に
渡す必要があります。

## コンテンツの作り方（`data/*/tierN/*.tres`）

各コンテンツ種別は素のGodot `Resource` スクリプト（`class_name` ＋ `@export` フィールド）なので、
新しいアイテムはGodotエディタのInspectorで編集した `.tres` ファイルを増やすだけで追加できます。
コードの変更は不要です。フォルダのパス（`tier1`、`tier2`、…）は人間が整理するためだけのもので、
**実際にどのプールへ入るかを決めるのはリソース自身が持つ `tier` フィールド**です（`DataLoader` が
参照するのはこちらです）。慣習としてフォルダとフィールドの値は揃えておくべきですが、実行時に
効くのはフィールドの方だけです。

| リソース | フィールド | 補足 |
|---|---|---|
| `TreasureData` | `id`, `display_name`, `tier`, `min_value`, `max_value`, `hp_damage`, `weight`, `icon`（Texture2D）, `buffs: Array[BuffData]` | 価値は配置のたびに `min_value`/`max_value` の範囲で1回だけロールされます。`icon` はHUDの所持お宝行に表示され、未設定の場合はHUD側で頭文字入りの色付き四角に自動フォールバックします。 |
| `EventData` | `id`, `tier`, `description`, `choice_a_text`, `choice_a_effect`, `choice_b_text`, `choice_b_effect` | `EVENT` マスに乗せる。2択のプロンプトを出す。 |
| `RelicData` | `id`, `display_name`, `tier`, `description`, `weight`, `buffs: Array[BuffData]` | `RELIC` マスに乗せる。スコアの無いお宝のように振る舞い、`PlayerState.carried_relics` に入って重量を永久に占有する。拾った瞬間にバフが永続付与される（脱落時も含めロストしない）。 |
| `EffectData` | `description`, `hp_delta`, `light_delta`, `score_delta`, `apply_buff`（BuffData）, `drop_treasure_count`, `next_treasure_multiplier` | イベントが使う汎用の効果データ。フィールドをデフォルト値（`0` / `1.0` / `null`）のままにしておけば「効果なし」として無視されるので、変えたいフィールドだけ設定すればOK。 |
| `BuffData` | `stat`（`MOVE` / `WEIGHT` / `LIGHT` / `MAX_HP` / `MAX_LIGHT`）, `amount`, `duration`（`PERMANENT` / `WHILE_HELD`） | 所持お宝由来の `WHILE_HELD` バフは、そのお宝を持っている間だけ効果があります。遺物のバフは `duration` の値に関係なく常に `PERMANENT` として付与されます。`MAX_HP`/`MAX_LIGHT` は遺物専用で、`PlayerState.add_relic_buffs` がこの2つだけ特別扱いし、動的なボーナスとして積むのではなく上限（と現在値）を直接引き上げます。 |

`BRIDGE` マスには専用のデータファイルはありません。「破壊するか、そのままにするか」の選択と
その効果は完全にコード側（`TurnManager._resolve_tile`/`choose_tile_action` と
`MapGraph.break_bridge`）で処理されます。

`.tres` の例（イベント、`data/events/tier1/hidden_draft.tres`）：

```ini
[gd_resource type="Resource" script_class="EventData" format=3]

[ext_resource type="Script" path="res://scripts/data_models/EventData.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data_models/EffectData.gd" id="2"]

[sub_resource type="Resource" id="1"]
script = ExtResource("2")
description = "You took the shortcut, burning extra light, but found a bit of loot"
light_delta = -1
score_delta = 3

[sub_resource type="Resource" id="2"]
script = ExtResource("2")
description = "You chose the safe path"

[resource]
script = ExtResource("1")
description = "You find a narrow gap with cold air blowing through. Take the shortcut?"
choice_a_text = "Take the shortcut (Light-1, Score+3)"
choice_a_effect = SubResource("1")
choice_b_text = "Turn back to the safe path"
choice_b_effect = SubResource("2")
```

実際には `.tres` を手書きするより、Godotエディタで同種の既存ファイルを複製し、Inspector上で
フィールドを書き換えて、対応する `data/<カテゴリ>/tierN/` フォルダに置く方が簡単です。

### tierの抽選（`TierSelector.gd`）

お宝／イベントのtierはマップファイルに書かれているわけではなく、マスの**深度**から実行時に
`TierSelector.pick_tier(depth)` で決まる固定の深度帯マッピングです：

- 深度1〜6 → tier1
- 深度7〜12 → tier2
- 深度13〜18 → tier3
- 深度19〜20 → tier4

`RELIC` マスも同じ `pick_tier(depth)` を独立に使用します。

あるtierに登録済みのアイテムが1つもない場合、`DataLoader` は数値的に最も近いtierへ自動的に
フォールバックします。つまりtierフォルダを空にしてもエラーにはならず、単に近いtierから借りて
くるだけです。

### 一見繋がっていそうで、まだ繋がっていないもの

- `MapNodeDef.fixed_event_id` は**実際に機能します**。値を設定すると、その `EVENT` マスはランダムな
  tier抽選ではなく、必ず指定したidのイベントになります（idが見つからない場合はランダム抽選に
  フォールバックします）。ただし `fixed_relic_id` は**どこからも参照されていません** — `RELIC`
  マスはこのフィールドの値に関わらず、常に `TreasureSpawner` によってtierからランダムに抽選されます。
- `MapNodeDef.tier`（ノードごとのtierフィールド）も同様に**どこからも読まれていません** — tierは
  常にそのノードの `depth` から `TierSelector` 経由で決まり、このフィールドの値は使われません。

マップファイルでこの2つのフィールドを設定しても何も変わらないように見える場合、それはマップ
ファイルの書き方の間違いではなく、単にその配線がまだ実装されていないだけなので、覚えておくと
良いです。
