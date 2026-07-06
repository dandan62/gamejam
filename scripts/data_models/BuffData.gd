extends Resource
class_name BuffData

## stat × duration の組み合わせで「永続+/-」「所持時のみ+/-」の4種類を表現する。
## Represents 4 kinds of modifiers via the stat × duration combination: permanent +/- and while-held +/-.

enum Stat { MOVE, WEIGHT, LIGHT }
enum Duration { PERMANENT, WHILE_HELD }

@export var stat: Stat = Stat.MOVE
@export var amount: int = 0
@export var duration: Duration = Duration.PERMANENT
