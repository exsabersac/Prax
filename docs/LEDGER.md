## v1 — Kin 年龄叶（setAge / ageAtLeast）

- **做了什么**：排他 `@age.<who>!<n>@`；条件 `ageAtLeast who n`（Match+Cmp Gte）供成年门禁。
- **测**：KinSpec setAge exclusive / rejects。

## v2 — Persona bearFromRegard

- **做了什么**：公理：任何人将 O 视为 `label` → 派生 `trait.O.<traitName>`（累犯入性格）。
- **测**：PersonaSpec derives / rejects dotted。

## v3 — Rumor gossipPublic

- **做了什么**：一对多告知（ForEach 听者），镜像 confessPublic；跳过主体与 Actor。
- **测**：RumorSpec deposits heard for every co-present hearer。

## v4 — Debt forgive

- **做了什么**：债权人动作：门禁 `debt.Actor.Debtor.<content>`，Delete 债务 + discharge 债务人。
- **测**：DebtSpec forgive clears debt and obligation。

## v5 — Chronicle leads-of / affiliates-of

- **做了什么**：`askChronicle` 查询首领与次级归属（`dbToSentences` 展平 `!`→`.`）。
- **测**：ChronicleSpec leads-of and affiliates-of。

## v6 — Kin primogeniture

- **做了什么**：长子继承 office——死亡持有者的存活子女中，无更年长者时 Actor 取得持有（需 `setAge`）。
- **测**：KinSpec primogeniture awards office to eldest living child。

## v7 — Emotion mood 基线心境

- **做了什么**：排他 `@mood.<who>!<emotion>@`；`setMood`/`clearMood`/`inMood`。与情节 feels 并存，不收缩决策空间。
- **测**：EmotionSpec setMood exclusive baseline。

## v8 — Confession liftDeceit

- **做了什么**：门禁于 `Actor.<kind>.H.<mark>`，Delete 听者对虚构事件的信念子树（解除欺骗；标记本身保留，可与 confess 搭配）。
- **测**：ConfessionSpec liftDeceit retracts hearer's fabricated belief。

## v9 — Chronicle debts-of

- **做了什么**：`askChronicle "debts of <who>"` 列出涉及 who 的债务事实（债权人或债务人）。
- **测**：ChronicleSpec debts-of。

## v10 — Debt callIn

- **做了什么**：债权人催债——`demanded.Actor.Debtor.<content>` + `breach Debtor breachLabel`。
- **测**：DebtSpec callIn marks demanded and breaches debtor。

## v11 — Project unenlist

- **做了什么**：Owner 将 Partner 移出 `@practice.<pid>.Actor.crew.Partner@`。
- **测**：ProjectSpec unenlist removes partner from crew。

## v12 — Faction transferLeadership

- **做了什么**：现任首领禅让给同派 Heir（排他 `leads` 覆盖）。
- **测**：FactionSpec transferLeadership。

## v13 — Host queryChronicle / explainActor / livingCast

- **做了什么**：薄封编年史查询、Inspect.explain、存活阵容名列表。
- **测**：HostSpec queryChronicle and livingCast and explainActor。

## v14 — Confession absolveAsLeader

- **做了什么**：赦免另需 `@leads.<faction>!Actor@`（祭司/族长薄角色）。
- **测**：ConfessionSpec absolveAsLeader requires faction leadership。

## v15 — Kin 关系条件

- **做了什么**：`isChildOf` / `isSiblingOf` / `isMarriedTo`。
- **测**：KinSpec relation conditions。

## v16 — Deceit liePublic

- **做了什么**：一对多捏造（ForEach 听者 + 每人 `lied` 标记），镜像 gossipPublic。
- **测**：DeceitSpec liePublic plants heard + lied marks。

## v17 — Arc leaveArc / adoptArc

- **做了什么**：`leaveArc` 清除阶段；`adoptArc` Actor 自愿进入新阶段的动作。
- **测**：ArcSpec leaveArc / adoptArc。

## v18 — Conversation onTopic / isSpeaker

- **做了什么**：对话实例门条件（topic! / speaker!Actor）。
- **测**：ConversationSpec onTopic / isSpeaker。

## v19 — Emotion moodFromFeeling

- **做了什么**：公理：`W.feels.E` → `mood.W!E`（可选安装的心境一致启动薄版）。
- **测**：EmotionSpec moodFromFeeling derives baseline mood。

## v20 — Sight lastKnownAt

- **做了什么**：条件：`seer.believes.at.seen!place`。
- **测**：SightSpec lastKnownAt。

## v21 — Feud 接线 factionStanding

- **做了什么**：`feudAxioms` 加入 `factionStanding "wronged.Offender.Victim" "feudbreaker"`；种子 kestrel 同志对 wronged 的信念。
- **测**：FeudSpec v93 regards carol/dave；esme 不触发。

## v22 — Faction isMember

- **做了什么**：条件 `isMember who faction`。
- **测**：FactionSpec isMember。

## v23 — Beliefs doubts / holdsBelief

- **做了什么**：议题级无信念 / 有信念条件。
- **测**：BeliefsSpec doubts / holdsBelief。

## v24 — Schedule pulse

- **做了什么**：无自动到期的周期心跳规则（对照 gathering）。
- **测**：ScheduleRuleSpec pulse。

## v25 — Host checkpoint / restore

- **做了什么**：薄封 `Persist.saveState`/`loadState`。
- **测**：HostSpec checkpoint / restore round-trip。

## v26 — Kin isParentOf

- **做了什么**：`isChildOf` 对偶条件。
- **测**：KinSpec parent dual。

## v27 — Witness neverSaw

- **做了什么**：`Absent` 于 `.seen` 叶。
- **测**：WitnessSpec neverSaw。

## v28 — Rumor heardFrom

- **做了什么**：具名来源传闻边条件。
- **测**：RumorSpec heardFrom。

## v29 — Persona hasTrait / lacksTrait

- **做了什么**：特质事实门条件。
- **测**：PersonaSpec hasTrait / lacksTrait。

## v30 — Emotion hasMood

- **做了什么**：任一基线心境子树条件。
- **测**：EmotionSpec hasMood。

## v31 — Chronicle mood-of

- **做了什么**：`askChronicle "mood of <who>"`。
- **测**：ChronicleSpec mood-of。

## v32 — Project part 智能构造

- **做了什么**：`part` 校验单路径段名（类型综合仍研究；防呆构造）。
- **测**：ProjectSpec part smart constructor rejects dotted names。

## v33 — Debt isOwed / hasCreditorClaim

- **做了什么**：债务人/债权人存在量词条件。
- **测**：DebtSpec isOwed / hasCreditorClaim existentials。

## v34 — Loop runPassive

- **做了什么**：跳过具名 idle 角色的 NPC 回放（玩家旁观夹具）。
- **测**：LoopSpec runPassive skips the idle name。

## v35 — Repute isNotorious

- **做了什么**：恶名昭著 Match 条件。
- **测**：ReputeSpec isNotorious。

## v36 — Confession hasMark

- **做了什么**：标记残叶 Match 条件（who.kind.hearer.markTail）。
- **测**：ConfessionSpec hasMark。

## v37 — Host queryMatching / factDelta

- **做了什么**：`queryMatching`/`queryViewMatching` 按针过滤基库/视图；`factDelta` 两态增删差分（事件订阅钩底物）。
- **测**：HostSpec queryMatching / queryViewMatching / factDelta。

## v38 — CLI prax worlds

- **做了什么**：文档化世界枚举：`prax worlds` 列出内置故事世界。
- **测**：构建 + usage 文案（无交互测）。

## v39 — 双集会并存

- **做了什么**：ScheduleRuleSpec 钉死 fair+chapel 独立周期并存（v37 残余）。
- **测**：ScheduleRuleSpec dual gatherings coexist。

## v40 — PRINCIPLES 吸血鬼时间尺度

- **做了什么**：文档对齐代码：`TimeScale::real`/`test` 已纠正；压缩须标明。
- **测**：文档一致性（无代码测）。

## v41 — Project part after 防呆

- **做了什么**：`part` 校验 `after` 依赖名为单路径段。
- **测**：ProjectSpec rejects dotted after-dependencies。

## v42 — Faction 村庄形夹具

- **做了什么**：FactionSpec 村庄形 guild/mill 夹具演示 `factionStanding`（不改 Village 金标准）。
- **测**：FactionSpec village-shaped guild fixture。

## v43 — Emotion lacksMood

- **做了什么**：`hasMood` 对偶条件。
- **测**：EmotionSpec lacksMood。

## v44 — Repute hasEsteemed

- **做了什么**：`esteemed.<observer>.<subject>.<label>` Match 条件。
- **测**：ReputeSpec hasEsteemed。

## v45 — Arc hasArc / lacksArc

- **做了什么**：`hasArc` / `lacksArc` 条件钉死角色是否处于某弧阶段槽。
- **测**：ArcSpec hasArc / lacksArc。

## v46 — Rumor neverHeard

- **做了什么**：`neverHeard` = Absent 任意 `.heard.Src` 叶（未听过某传闻）。
- **测**：RumorSpec neverHeard。

## v47 — Kin isInLawOf

- **做了什么**：`isInLawOf` Match 派生 `inLaw.A.B` 路径。
- **测**：KinSpec isInLawOf。

## v48 — Chronicle arc-of / age-of / siblings-of

- **做了什么**：`askChronicle` 扩展：弧阶段、年龄、兄弟姐妹列表。
- **测**：ChronicleSpec arc-of / age-of / siblings-of。

## v49 — Host availableMatching

- **做了什么**：按针过滤可用菜单标签（`available` 的过滤对偶）。
- **测**：HostSpec availableMatching。

## v50 — Conversation isListener

- **做了什么**：`isListener` = 听者排他叶（`isSpeaker` 对偶）。
- **测**：ConversationSpec isListener。

## v51 — Deceit liedTo / hasLied

- **做了什么**：谎言标记路径条件与存在量词。
- **测**：DeceitSpec liedTo / hasLied。

## v52 — Faction lacksMember

- **做了什么**：`isMember` 对偶 Not 条件。
- **测**：FactionSpec lacksMember。

## v53 — Project isCrewOf / hasCompletedPart

- **做了什么**：crew 与部件账本 Match 条件。
- **测**：ProjectSpec isCrewOf / hasCompletedPart。

## v54 — Debt neverOwed

- **做了什么**：`isOwed` 对偶 Absent。
- **测**：DebtSpec neverOwed。

## v55 — Sight unknownWhere

- **做了什么**：无任何最后已知位置叶。
- **测**：SightSpec unknownWhere。

## v56 — Host livingMatching

- **做了什么**：按针过滤存活阵容。
- **测**：HostSpec livingMatching。

## v57 — Repute lacksEsteemed

- **做了什么**：`hasEsteemed` 对偶。
- **测**：ReputeSpec lacksEsteemed。

## v58 — Confession isAbsolved

- **做了什么**：赦免击败者叶 Match（如 `recanted.<who>`）。
- **测**：ConfessionSpec isAbsolved。

## v59 — Schedule festival

- **做了什么**：`festival` = `gathering` + 同寿命 `festival.<name>` 叶，供节庆门禁。
- **测**：ScheduleRuleSpec festival seeds leaf。

## v60 — Core hasBond / lacksBond

- **做了什么**：公开对称纽带叶子的 Match / Absent 条件。
- **测**：CoreSpec hasBond / lacksBond。

## v61 — Emotion lacksFeeling

- **做了什么**：`feels` 路径的 Not 对偶。
- **测**：EmotionSpec lacksFeeling。

## v62 — Reactions noViolation

- **做了什么**：规范违反叶的 Not 对偶。
- **测**：ReactionsSpec noViolation。

## v63 — Host factDeltaMatching

- **做了什么**：按针过滤 `factDelta` 增/删两侧（事件订阅钩底物）。
- **测**：HostSpec factDeltaMatching。

## v64 — CLI prax version

- **做了什么**：打印 `formatVersion`（持久化格式标签）。
- **测**：手工 `prax version` → `prax-state v4`。

## v65 — Faction lacksAffiliate / lacksLeader

- **做了什么**：次级归属与领导叶的 Not 对偶。
- **测**：FactionSpec lacksAffiliate / lacksLeader。

## v66 — Kin neverMarried

- **做了什么**：无 `married.<who>` 子树的 Absent 条件。
- **测**：KinSpec neverMarried。

## v67 — Deontic neverObliged

- **做了什么**：义务路径的 Not 对偶。
- **测**：DeonticSpec neverObliged。

## v68 — Host queryChronicleMatching / explainActorMatching

- **做了什么**：编年史答与检查器解释行的针过滤；`Prax.Inspect.explainMatching`。
- **测**：HostSpec queryChronicleMatching / explainActorMatching。

## v69 — Kin neverParent

- **做了什么**：无 `parent.<who>` 子树的 Absent 条件。
- **测**：KinSpec neverParent。

## v70 — Sight knownWhere

- **做了什么**：最后已知位置子树存在的 Match 对偶。
- **测**：SightSpec knownWhere。

## v71 — Confession neverMarked

- **做了什么**：标记路径的 Not 对偶。
- **测**：ConfessionSpec neverMarked。

## v72 — Host practiceNames

- **做了什么**：枚举顶层 `practice.<id>` 名（无实例后缀）。
- **测**：HostSpec practiceNames。

## v73 — Rumor everHeard

- **做了什么**：`.heard.Src` 叶存在的 Match 对偶。
- **测**：RumorSpec everHeard。

## v74 — Project lacksCrewOf / lacksCompletedPart

- **做了什么**：crew / 部件账本的 Not 对偶。
- **测**：ProjectSpec lacksCrewOf / lacksCompletedPart。

## v75 — Host deadCast

- **做了什么**：阵容中已标 `dead.<name>` 的角色名列表。
- **测**：HostSpec deadCast。

## v76 — Host practiceNames（读 practiceDefs）

- **做了什么**：枚举已定义实践 id（`Map.keys practiceDefs`）。
- **测**：HostSpec practiceNames。

## v77 — CLI prax practices \<world\>

- **做了什么**：对内置世界打印 `practiceNames`。
- **测**：手工 `prax practices village|bar`。

## v78 — Emotion lacksFeelingToward

- **做了什么**：有目标感受叶的 Not 对偶。
- **测**：EmotionSpec lacksFeelingToward。

## v79 — Debt lacksCreditorClaim

- **做了什么**：债权人主张子树的 Absent 对偶。
- **测**：DebtSpec lacksCreditorClaim。

## v80 — Host castNames

- **做了什么**：全阵容名（含死者）。
- **测**：HostSpec castNames。

## v81 — Schedule duringFestival / outsideFestival

- **做了什么**：节庆叶的 Match/Not 条件对偶，供创作门禁「节庆中才可 / 节庆外拒绝」。
- **测**：ScheduleRuleSpec duringFestival 对偶 + harvest rite 沙盒门禁弧。

## v82 — Coerce isThreatened / lacksThreatened 等精确叶对偶

- **做了什么**：`threatened` / `defied` / `complied` / `extorted` 事实路径的 Match/Not 智能构造器。
- **测**：CoerceSpec condition duals。

## v83 — Coerce ever*/never*（按 coercion id）

- **做了什么**：对某一 `sid` 下任意威胁/违抗/服从标记的 Exists/Absent 对偶。
- **测**：CoerceSpec ever*/never*。

## v84 — Faction regardsAs / lacksRegard / everRegards / neverRegards

- **做了什么**：站队叶 `regards.<who>.<target>.<label>` 的条件对偶与存在量词。
- **测**：FactionSpec regards duals。

## v85 — Village 形 mill 夹具（仍不改金标准）

- **做了什么**：在 FactionSpec 再补 mill 共成员站队夹具（dave/fran 视 bob 为 thief）。
- **测**：FactionSpec village-shaped mill fixture。

## v86 — Host regardsOf

- **做了什么**：从闭合视图枚举 `@who@` 发出的 `regards.<who>.*` 叶。
- **测**：HostSpec regardsOf。

## v87 — CLI prax cast [living] \<world\>

- **做了什么**：对内置世界打印 `castNames` 或 `livingCast`。
- **测**：手工 `prax cast village` / `prax cast living village`。

## v88 — Deceit lacksLied / neverLied

- **做了什么**：撒谎标记的 Not / Absent 对偶（精确听者事件 / 任意撒谎痕迹）。
- **测**：DeceitSpec lacksLied / neverLied。

## v89 — Repute lacksNotorious / hasScorned / lacksScorned

- **做了什么**：恶名与 scorned 站队叶的 Match/Not 条件对偶。
- **测**：ReputeSpec lacksNotorious / hasScorned / lacksScorned。

## v90 — Witness everSaw

- **做了什么**：`.seen` 叶的 Exists 对偶（与 neverSaw 对称）。
- **测**：WitnessSpec everSaw。

## v91 — Conversation offTopic / hasChattedWith / neverChattedWith

- **做了什么**：话题与闲聊史的 Not/Match 条件对偶。
- **测**：ConversationSpec offTopic / chattedWith duals。

## v92 — Beliefs disbelievesThat

- **做了什么**：`believesThat` 路径的 Not 对偶。
- **测**：BeliefsSpec disbelievesThat。

## v93 — Host membersOf / affiliatesOf

- **做了什么**：从闭合视图枚举派系成员与个人附属（稳定排序）。
- **测**：HostSpec membersOf / affiliatesOf。

## v94 — Chronicle members of

- **做了什么**：`askChronicle "members of <faction>"` 列出 `member.<who>.<faction>`。
- **测**：ChronicleSpec members-of。

## v95 — Kin lacksChildOf / lacksSiblingOf / lacksMarriedTo / lacksInLawOf

- **做了什么**：亲属精确叶的 Not 对偶（与 neverMarried/neverParent 的 Absent 量词互补）。
- **测**：KinSpec lacks* duals。

## v96 — Confession lacksAbsolved

- **做了什么**：赦免叶的 Not 对偶。
- **测**：ConfessionSpec lacksAbsolved。

## v97 — Debt lacksOwes

- **做了什么**：精确债务叶的 Not 对偶。
- **测**：DebtSpec lacksOwes。

## v98 — Coerce everExtorted / neverExtorted

- **做了什么**：按 coercion id 的勒索痕 Exists/Absent 对偶（补齐 threaten/defy/comply 的 ever/never 族）。
- **测**：CoerceSpec everExtorted / neverExtorted。

## v99 — Host leadersOf

- **做了什么**：从闭合视图枚举 `@leads.<faction>.<who>@`（稳定排序）。
- **测**：HostSpec leadersOf。

## v100 — CLI prax dead \<world\>

- **做了什么**：对内置世界打印 `deadCast`。
- **测**：手工 `prax dead village`。

## v101 — CLI prax members / affiliates

- **做了什么**：`prax members <faction> <world>`、`prax affiliates <who> <world>`。
- **测**：手工 smoke。

## v102 — CLI prax leaders \<faction\> \<world\>

- **做了什么**：对内置世界打印 `leadersOf`。
- **测**：手工 smoke。

## v103 — Rumor lacksHeardFrom

- **做了什么**：精确来源传闻叶的 Not 对偶。
- **测**：RumorSpec lacksHeardFrom。

## v104 — Emotion everFeeling / neverFeeling

- **做了什么**：任意情感叶的 Exists/Absent 对偶。
- **测**：EmotionSpec everFeeling / neverFeeling。

## v105 — Repute everNotorious / neverNotorious

- **做了什么**：任意恶名标签的 Exists/Absent 对偶。
- **测**：ReputeSpec everNotorious / neverNotorious。

## v106 — Host regardsToward

- **做了什么**：从闭合视图枚举指向 @target@ 的站队叶。
- **测**：HostSpec regardsToward。

## v107 — Host factionsNamed

- **做了什么**：从 member/affiliate/leads 叶收集派系名（去重排序）。
- **测**：HostSpec factionsNamed。

## v108 — CLI prax factions \<world\>

- **做了什么**：对内置世界打印 `factionsNamed`。
- **测**：手工 `prax factions feud`。

## v109 — CLI prax regards

- **做了什么**：`prax regards <who> <world>`（发出）与 `prax regards toward <target> <world>`（指向）。
- **测**：手工 smoke。

## v110 — Persona everTrait / neverTrait

- **做了什么**：任意性格叶的 Exists/Absent 对偶。
- **测**：PersonaSpec everTrait / neverTrait。

## v111 — Faction everMember / neverMember

- **做了什么**：任意派系主成员叶的 Exists/Absent 对偶。
- **测**：FactionSpec everMember / neverMember。

## v112 — Village 形 church 夹具（仍不改金标准）

- **做了什么**：FactionSpec 再补 church 共成员站队夹具（priest/gale 视 eve 为 heretic）。
- **测**：FactionSpec village-shaped church fixture。

## v113 — AnalysisTable feudPin 对齐 v93 factionStanding

- **做了什么**：全量回归发现 feud 分析表金标准仍停在 factionStanding 接入前；按当前 `feudWorld` 刷新 footprint/axiomHead（Village 金标准未动）。
- **测**：`stack test -p AnalysisTable`；全量 `stack test`。

## v114 — Deontic lacksObliged / hasObligations / lacksObligations

- **做了什么**：补齐义务条件对偶——点级 `lacksObliged`（与历史 `neverObliged` 同体），以及任意义务的 Exists/Absent（`hasObligations` / `lacksObligations`）。
- **测**：DeonticSpec lacksObliged / hasObligations / lacksObligations。

## v115 — Project everCrew / neverCrew / everCompletedPart / neverCompletedPart

- **做了什么**：事业 crew 与完成账本的 Exists/Absent 量词对偶。
- **测**：ProjectSpec everCrew / neverCrew / everCompletedPart / neverCompletedPart。

## v116 — Beliefs everBelieves / neverBelieves

- **做了什么**：角色级任意信念叶的 Exists/Absent 对偶（议题级仍用 holdsBelief/doubts）。
- **测**：BeliefsSpec everBelieves / neverBelieves。

## v117 — Host debtsOf

- **做了什么**：从闭合视图枚举与 @who@ 相关的 `debt.*` 叶（债权人或债务人一侧）。
- **测**：HostSpec debtsOf。

## v118 — CLI prax debts \<who\> \<world\>

- **做了什么**：对内置世界打印 `debtsOf`。
- **测**：手工 `prax debts ana village` smoke（空列表亦可）。

## v119 — Faction everAffiliate / neverAffiliate / everLeader / neverLeader

- **做了什么**：次级归属与领导的 Exists/Absent 量词对偶。
- **测**：FactionSpec everAffiliate / everLeader。

## v120 — Conversation lacksChattedWith / everChatted / neverChatted

- **做了什么**：点级 `lacksChattedWith`（与历史 `neverChattedWith` 同体）；任意聊天叶 Exists/Absent。
- **测**：ConversationSpec lacksChattedWith / everChatted / neverChatted。

## v121 — Repute everEsteemed / neverEsteemed / everScorned / neverScorned

- **做了什么**：观察者侧 esteem/scorn 一次守卫叶的 Exists/Absent 对偶。
- **测**：ReputeSpec everEsteemed / everScorned。

## v122 — Kin everMarried / everParent

- **做了什么**：补齐 `neverMarried` / `neverParent` 的 Exists 对偶。
- **测**：KinSpec everMarried / everParent。

## v123 — Witness lacksSaw

- **做了什么**：@saw@ 的点级 Not 对偶（与 Exists/Absent 的 everSaw/neverSaw 区分）。
- **测**：WitnessSpec lacksSaw。

## v124 — Arc lacksArcIs

- **做了什么**：@arcIs@ 的 Not 对偶（特定舞台）。
- **测**：ArcSpec lacksArcIs。

## v125 — Host obligationsOf

- **做了什么**：从闭合视图枚举 `obliged.<who>.*` 义务叶（含 whenAt 作用域）；对齐 debtsOf/regardsOf 风格（完整叶，非 Deontic 内容后缀）。
- **测**：HostSpec obligationsOf。

## v126 — CLI prax obligations \<who\> \<world\>

- **做了什么**：对内置世界打印 `obligationsOf`。
- **测**：手工 `prax obligations bex bar` smoke（开局空列表亦可）。

## v127 — 节庆门禁丰收起誓叙事沙盒

- **做了什么**：ScheduleRuleSpec 可玩弧——节前备祭 → 节中起誓种义务 → 节后兑现 discharge；仍不改 Village 金标准。
- **测**：ScheduleRuleSpec harvest vow arc。

## v128 — Emotion everFeelingToward / neverFeelingToward

- **做了什么**：指向性情感叶的 Exists/Absent 量词对偶。
- **测**：EmotionSpec everFeelingToward / neverFeelingToward。

## v129 — Reactions lacksViolation / everViolated / neverViolated

- **做了什么**：`lacksViolation` = `noViolation` 同体；违规叶 Exists/Absent 量词对偶。
- **测**：ReactionsSpec lacksViolation / everViolated / neverViolated。

## v130 — Kin everInLaw / neverInLaw

- **做了什么**：姻亲派生叶的 Exists/Absent 量词对偶。
- **测**：KinSpec everInLaw / neverInLaw。

## v131 — Host breachesOf

- **做了什么**：从闭合视图枚举 `violated.<who>.*` 违规叶。
- **测**：HostSpec breachesOf。

## v132 — CLI prax breaches \<who\> \<world\>

- **做了什么**：对内置世界打印 `breachesOf`。
- **测**：手工 `prax breaches bex bar` smoke（开局空列表亦可）。

## v133 — Deceit everLied

- **做了什么**：`everLied` = `hasLied` 同体（对齐 ever* 命名）。
- **测**：DeceitSpec everLied aliases hasLied。

## v134 — Debt everOwed

- **做了什么**：`everOwed` = `isOwed` 同体（对齐 ever* 命名）。
- **测**：DebtSpec everOwed aliases isOwed。

## v135 — Confession lacksMark

- **做了什么**：`lacksMark` = `neverMarked` 同体（对齐 lacks* 命名）。
- **测**：ConfessionSpec lacksMark aliases neverMarked。

## v136 — Host feelingsOf / liesOf / chattedWithOf

- **做了什么**：从闭合视图枚举 `@who@.feels.*` / `@who@.lied.*` / `@who@.chattedWith.*`。
- **测**：HostSpec feelingsOf / liesOf / chattedWithOf。

## v137 — CLI prax feelings / lies / chatted

- **做了什么**：对内置世界打印上述三视图。
- **测**：手工 smoke（开局空列表亦可）。

## v138 — 节庆起誓违约弧

- **做了什么**：ScheduleRuleSpec 在窗外 `shirk` → `breach` 记录违规；与兑现弧对偶。
- **测**：ScheduleRuleSpec harvest vow arc shirk path。

## v139 — Host traitsOf / moodsOf / bondsOf / kinOf / notoriousOf

- **做了什么**：闭合视图枚举 `trait.<who>.*`、`mood.<who>.*`、`bond.<who>.*`、亲属叶（married/parent/sibling/inLaw/grandparent 任一侧含 who）、`notorious.<who>.*`。
- **测**：HostSpec traitsOf / moodsOf / bondsOf / kinOf / notoriousOf。

## v140 — CLI prax traits / moods / bonds / kin / notorious

- **做了什么**：对内置世界打印上述五视图。
- **测**：手工 smoke（开局空列表亦可）。

## v141 — Arc everArc / neverArc

- **做了什么**：弧阶段 Exists/Absent 量词对偶（与 Match/Not 的 hasArc/lacksArc 区分）。
- **测**：ArcSpec everArc / neverArc。

## v142 — Core everBond / neverBond

- **做了什么**：公开纽带 Exists/Absent 量词对偶。
- **测**：CoreSpec everBond / neverBond。

## v143 — Rumor lacksHeard

- **做了什么**：`lacksHeard` = `neverHeard` 同体（对齐 lacks* 命名）。
- **测**：RumorSpec lacksHeard aliases neverHeard。

## v144 — 节庆婚礼叙事沙盒

- **做了什么**：ScheduleRuleSpec 可玩弧——节前求亲 → 节中成婚写双边 married → 节后宴贺；仍不改 Village 金标准。
- **测**：ScheduleRuleSpec harvest wedding arc。

## v145 — Host esteemedOf / scornedOf / beliefsOf

- **做了什么**：闭合视图枚举 `esteemed.<who>.*`、`scorned.<who>.*`、`<who>.believes.*`。
- **测**：HostSpec esteemedOf / scornedOf / beliefsOf。

## v146 — CLI prax esteemed / scorned / beliefs

- **做了什么**：对内置世界打印上述三视图。
- **测**：手工 smoke（开局空列表亦可）。

## v147 — Emotion everMood / neverMood

- **做了什么**：基线心境 Exists/Absent 量词对偶（与 Match/Not 的 hasMood/lacksMood 区分）。
- **测**：EmotionSpec everMood / neverMood。

## v148 — Kin everSibling / neverSibling

- **做了什么**：兄弟姐妹叶 Exists/Absent 量词对偶。
- **测**：KinSpec everSibling / neverSibling。

## v149 — Witness hasSaw

- **做了什么**：`hasSaw` = `saw` 同体（对齐 has* 命名）。
- **测**：WitnessSpec hasSaw aliases saw。

## v150 — Sight lacksKnownWhere

- **做了什么**：`lacksKnownWhere` = `unknownWhere` 同体（对齐 lacks* 命名）。
- **测**：SightSpec lacksKnownWhere aliases unknownWhere。

## v151 — Beliefs lacksBelief

- **做了什么**：`lacksBelief` = `neverBelieves` 同体（对齐 lacks* 命名）。
- **测**：BeliefsSpec lacksBelief aliases neverBelieves。

## v152 — 节庆狂欢心境沙盒

- **做了什么**：ScheduleRuleSpec 可玩弧——节中 revel 种 festive 心境 → 节后 sober 清除；仍不改 Village。
- **测**：ScheduleRuleSpec harvest revel arc。

## v153 — Host arcsOf / agesOf / projectsOf

- **做了什么**：闭合视图枚举 `<who>.arc.*`、`age.<who>.*`、以及角色为第二段的 `practice.<pid>.<who>.*` 事业实例叶。
- **测**：HostSpec arcsOf / agesOf / projectsOf。

## v154 — CLI prax arcs / ages / projects

- **做了什么**：对内置世界打印上述三视图。
- **测**：手工 smoke（开局空列表亦可）。

## v155 — Conversation lacksSpeaker / lacksListener

- **做了什么**：对话说话人/听者角色叶的 Not 对偶。
- **测**：ConversationSpec lacksSpeaker / lacksListener。

## v156 — Reactions everBreach

- **做了什么**：`everBreach` = `everViolated` 同体（对齐 breach 命名）。
- **测**：ReactionsSpec everBreach aliases everViolated。

## v157 — Deontic everObliged

- **做了什么**：`everObliged` = `hasObligations` 同体（对齐 ever* 命名）。
- **测**：DeonticSpec everObliged aliases hasObligations。

## v158 — Debt isDemanded / lacksDemanded / everDemanded / neverDemanded

- **做了什么**：催收叶 `demanded.<creditor>.<debtor>.<content>` 的 Match/Not 与 Exists/Absent 对偶。
- **测**：DebtSpec isDemanded / lacksDemanded / everDemanded / neverDemanded。

## v159 — Reactions neverBreach

- **做了什么**：`neverBreach` = `neverViolated` 同体（对齐 breach 命名）。
- **测**：ReactionsSpec neverBreach aliases neverViolated。

## v160 — Confession everMarked / everAbsolved

- **做了什么**：`everMarked` = `hasMark`、`everAbsolved` = `isAbsolved` 同体（对齐 ever* 命名）。
- **测**：ConfessionSpec everMarked / everAbsolved。

## v161 — Beliefs hasBelief

- **做了什么**：`hasBelief` = `everBelieves` 同体（对齐 has* 命名）。
- **测**：BeliefsSpec hasBelief aliases everBelieves。

## v162 — Host demandedOf + CLI prax demanded

- **做了什么**：闭合视图枚举与角色相关的 `demanded.<creditor>.<debtor>.*`；CLI 打印。
- **测**：HostSpec demandedOf。

## v163 — Host festivalsOf + CLI prax festivals

- **做了什么**：闭合视图枚举开放 `festival.*` 叶；CLI 打印。
- **测**：HostSpec festivalsOf。

## v164 — 节庆请愿叙事沙盒

- **做了什么**：ScheduleRuleSpec 可玩弧——窗外起草 → 节中呈递 → 节后获批；仍不改 Village。
- **测**：ScheduleRuleSpec harvest petition arc。

## v165 — Conversation everChattedWith

- **做了什么**：`everChattedWith` = `hasChattedWith` 同体（对齐 ever* 命名）。
- **测**：ConversationSpec everChattedWith。

## v166 — Emotion hasFeeling / hasFeelingToward

- **做了什么**：`hasFeeling`/`hasFeelingToward` = `feeling`/`feelingToward` 同体。
- **测**：EmotionSpec hasFeeling / hasFeelingToward。

## v167 — Rumor hasHeard / hasHeardFrom

- **做了什么**：`hasHeard`/`hasHeardFrom` = `heard`/`heardFrom` 同体。
- **测**：RumorSpec hasHeard / hasHeardFrom。

## v168 — Arc hasArcIs

- **做了什么**：`hasArcIs` = `arcIs` 同体。
- **测**：ArcSpec hasArcIs。

## v169 — Sight hasKnownWhere

- **做了什么**：`hasKnownWhere` = `knownWhere` 同体。
- **测**：SightSpec hasKnownWhere。

## v170 — Schedule hasFestival / lacksFestival

- **做了什么**：`hasFestival`/`lacksFestival` = `duringFestival`/`outsideFestival` 同体。
- **测**：ScheduleRuleSpec hasFestival / lacksFestival。

## v171 — Host locationsOf + CLI prax locations

- **做了什么**：闭合视图枚举 `at.<who>.*`；CLI 打印。
- **测**：HostSpec locationsOf。

## v172 — Faction hasMember / hasLeader / hasAffiliate / hasRegardAs

- **做了什么**：`hasMember`/`hasLeader`/`hasAffiliate`/`hasRegardAs` = `isMember`/`isLeader`/`affiliates`/`regardsAs` 同体。
- **测**：FactionSpec has* aliases。

## v173 — Kin hasChildOf / hasSiblingOf / hasMarriedTo / hasParentOf / hasInLawOf

- **做了什么**：亲属关系 `has*` = `is*` 同体。
- **测**：KinSpec has* aliases。

## v174 — Repute hasNotorious

- **做了什么**：`hasNotorious` = `isNotorious` 同体。
- **测**：ReputeSpec hasNotorious。

## v175 — Host holdingOf / carryingOf / shunnedOf + CLI

- **做了什么**：闭合视图枚举持有/携带/排斥叶；CLI `prax holding`/`carrying`/`shunned`。
- **测**：HostSpec holdingOf / carryingOf / shunnedOf。

## v176 — 节庆审判叙事弧

- **做了什么**：ScheduleRuleSpec 沙盒：窗外控告 → 窗内审判 → 窗外宣判（`festival.harvest` 门禁）。
- **测**：ScheduleRuleSpec harvest trial arc。

## v177 — CLI help 补全 demanded/festivals/locations/holding/carrying/shunned

- **做了什么**：`usageText` 补上此前已落地但未进 help 的视图命令。
- **测**：无单独 Spec（文档/help）；与既有 CLI 同源。

## v178 — Conversation hasSpeaker / hasListener / hasTopic

- **做了什么**：`hasSpeaker`/`hasListener`/`hasTopic` = `isSpeaker`/`isListener`/`onTopic` 同体。
- **测**：ConversationSpec hasSpeaker / hasListener / hasTopic。

## v179 — Deontic hasObliged

- **做了什么**：`hasObliged` = `isObliged` 同体。
- **测**：DeonticSpec hasObliged。

## v180 — Debt hasOwes / hasOwed / hasDemanded

- **做了什么**：`hasOwes`/`hasOwed`/`hasDemanded` = `owes`/`isOwed`/`isDemanded` 同体。
- **测**：DebtSpec hasOwes / hasOwed / hasDemanded。

## v181 — Project hasCrewOf

- **做了什么**：`hasCrewOf` = `isCrewOf` 同体。
- **测**：ProjectSpec hasCrewOf。

## v182 — Beliefs hasBelievesThat / hasHoldsBelief

- **做了什么**：`hasBelievesThat`/`hasHoldsBelief` = `believesThat`/`holdsBelief` 同体。
- **测**：BeliefsSpec hasBelievesThat / hasHoldsBelief。

## v183 — Emotion hasInMood

- **做了什么**：`hasInMood` = `inMood` 同体。
- **测**：EmotionSpec hasInMood。

## v184 — Host threatenedOf / extortedOf + CLI

- **做了什么**：闭合视图枚举胁迫/勒索叶；CLI `prax threatened`/`extorted`；help 同步。
- **测**：HostSpec threatenedOf / extortedOf。

## v185 — 节庆守灵叙事弧

- **做了什么**：ScheduleRuleSpec 沙盒：窗外守灵 → 窗内悼词 → 窗外下葬。
- **测**：ScheduleRuleSpec harvest mourning arc。

## v186 — Reactions hasViolation

- **做了什么**：`hasViolation` = `violationOf` 同体。
- **测**：ReactionsSpec hasViolation。

## v187 — Repute hasRegardedAs

- **做了什么**：`hasRegardedAs` = `regardedAs` 同体。
- **测**：ReputeSpec hasRegardedAs。

## v188 — Host compliedOf / defiedOf + CLI

- **做了什么**：闭合视图枚举顺从/违抗叶；CLI `prax complied`/`defied`；help 同步。
- **测**：HostSpec compliedOf / defiedOf。

## v189 — 节庆市集叙事弧

- **做了什么**：ScheduleRuleSpec 沙盒：窗外备货 → 窗内议价 → 窗外结账。
- **测**：ScheduleRuleSpec harvest market arc。

## v190 — 村庄形磨坊正义弧（factionStanding 实践门禁）

- **做了什么**：FactionSpec 多步夹具：mill 成员获知偷窃 → 派生 thief 站队 → `confront` 门禁于 regard → 叛逃溶解门禁而信念基事实仍在。Village 角色名作夹具；**未改** Village 金标准。
- **测**：FactionSpec village-shaped mill justice arc。

## v191 — 村庄形教会审查弧

- **做了什么**：FactionSpec：church 成员听闻亵渎 → heretic 站队 → `censure` 门禁；guild 旁观者同信念无站队、无审查。
- **测**：FactionSpec village-shaped church censure arc。

## v192 — 村庄形 affiliate 负例

- **做了什么**：证明 `factionStanding` 只接合主成员 `member.!` 脊骨；仅次级 `affiliate` 的信念不派生站队，而 `affiliateComrades` 同盟仍成立。
- **测**：FactionSpec village-shaped affiliate negative。

## v193 — 节庆磨坊审判复合弧

- **做了什么**：ScheduleRuleSpec：窗外获知 → 窗内控告（门禁于 factionStanding 派生 regard）→ 窗外放逐；多角色（dave/fran/eve）对照。
- **测**：ScheduleRuleSpec harvest mill tribunal arc。

## v194 — 节庆教会异端弧（领袖门禁）

- **做了什么**：ScheduleRuleSpec：窗外听闻 → 窗内审查 → 窗外仅 `isLeader` 可放逐；复合节庆 + factionStanding + appointLeader。
- **测**：ScheduleRuleSpec harvest church heresy arc。

## v195 — 村庄形受害方叛逃溶解站队

- **做了什么**：FactionSpec：受害方 carol 离开 mill 后，同派 dave 的 thief 站队溶解（`factionStanding` 接合受害方*当前*主成员）；信念基事实仍在。
- **测**：FactionSpec village-shaped victim defection dissolves co-member regards。

## v196 — 村庄形婚入磨坊获得站队

- **做了什么**：FactionSpec：fran（guild）已信偷窃但无站队；`wed` 入 mill 后与受害方共成员，派生 thief 站队并打开 confront 门禁。跨 `Prax.Kin`/`Prax.Faction`；Village 金标准未动。
- **测**：FactionSpec village-shaped wedding into mill grants factionStanding regard。

## v197 — 可玩沙盒世界（节庆 + factionStanding 弧）

- **做了什么**：新模块 `Prax.Worlds.Sandbox`（非 Village）：磨坊审判（窗外获知 → 窗内控告 → 窗外放逐）、教会异端（听闻 → 审查 → 仅领袖放逐）、婚入磨坊获站队；复用既有 `factionStanding` / `festival` / `Kin` / `Host`，少造原语。CLI `prax sandbox`；`prax practices`/`cast`/`worlds` 等已挂名。
- **测**：SandboxSpec 五案逐步断言（typeCheck、种子、三条叙事弧）；Village / GoldenDrive / 既有金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置。

## v198 — Sandbox 轻量 wants 驱动可玩节拍

- **做了什么**：`Prax.Worlds.Sandbox` 挂命名欲望词汇（磨坊获知/控告/放逐、教会听闻/审查/放逐、婚入磨坊）与 `presence` 等待实践；NPC 在门禁满足时由 planner 自选叙事节拍（非仅 Spec 手推 Outcome）。Sandbox 自有短轨迹期望（`SandboxSpec.sandboxGolden`，独立于 GoldenDrive / Village）。
- **测**：SandboxSpec pickAction 种子/节庆窗内/窗外断言；35 步 NPC 自由跑金轨迹至双放逐；原有三条逐步弧与 typeCheck 仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置。

## v199 — Sandbox 债务买沉默 × 磨坊正义弧

- **做了什么**：`Prax.Worlds.Sandbox` 新实践 `millSilence`：贼（bob）在窗外向已 `factionStanding` 站队的证人买人情封口（`Prax.Debt.owe`）；控告门禁叠加 `lacksOwes`，未结清沉默债不可控告；债权人可撕毁协议（`settle` + `revoked` 叶）后恢复控告，债务人亦可偿还。新磨坊证人 `ira` 带 `breaks-silence-deal` want；bob 带 `buys-ira-silence`。主金轨迹扩展纳入买沉默→撕毁→控告；另增 `sandboxSilenceGolden` 从 ira 已获知种子起的独立短轨迹。
- **测**：SandboxSpec 逐步沉默债（买封控告 / 撕毁恢复 / 偿还无 revoked）；pickAction 买/撕；39 步主金 + 32 步沉默金；原磨坊/教会/婚入弧仍绿。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v200 — Sandbox 双节庆错峰门禁（harvest × market）

- **做了什么**：`Prax.Worlds.Sandbox` 并挂 `festival "harvest" 3 1` 与 `festival "market" 4 1`（回合 3 仅丰收、回合 4 仅市集）；新实践 `marketCry`：已 `factionStanding` 站队的磨坊成员仅在 market 窗内可「市集喊冤」；欲望 `cries-theft-at-market`（权重 7 < 控告 8，故 harvest 窗优先控告）。主金与沉默金轨迹扩展纳入喊冤节拍。加分：次级归属角色 `kyle`（`affiliate` mill、主效忠 guild、已信偷窃）作可玩负例——无站队、无控告/喊冤。
- **测**：SandboxSpec 错峰逐步（t3 denounce / t4 cry）；kyle affiliate 负例；pickAction harvest vs market；44 步主金 + 44 步沉默金。原磨坊/教会/婚入/沉默弧仍绿。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v201 — Sandbox 受害方叛逃溶解站队后再入派和解

- **做了什么**：新实践 `millAllegiance`：受害方（已信 `stole.bob.Actor`）可「弃磨坊投公会」→ `joins` 覆盖主成员，同派 `factionStanding` 站队溶解（信念基事实仍在），控告门禁失效；再「和解归磨坊」→ 站队与控告恢复。欲望 `flees-mill` / `returns-to-mill`；主阵容 carol 不挂叛逃 want（免搅主金），`defectionSeed` 覆盖其欲望后自由跑。
- **测**：SandboxSpec 逐步叛逃溶解 / 归队恢复；pickAction 弃→归；35 步 `sandboxDefectionGolden`。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v202 — Sandbox 沉默×叛逃×节庆复合门禁弧

- **做了什么**：同一条可玩弧交叉 `millSilence` + `millAllegiance` + 双节庆门禁：买沉默封 ira 控告 → 受害方 carol 叛逃溶解**全体**磨坊站队（撕毁债后控告仍闭）→ 和解归队恢复站队 → harvest 控告 / market 喊冤。`compositeSeed` 覆盖 carol 叛逃 want；逐步断言钉多重门禁翻转；44 步 `sandboxCompositeGolden`。
- **测**：SandboxSpec 复合逐步 + wants pick + 44 步金；原磨坊/教会/婚入/沉默/错峰/叛逃金仍绿。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v203 — Sandbox 臭名+愤怒驱动市集声援（旁观者介入）

- **做了什么**：沙盒公理加 `notoriety "thief" 2`；磨坊「获知」同时 `feelToward` 愤怒；新实践 `millRally`——market 窗内、已愤怒且 bob 达臭名阈值时可「声援广场」。欲望 `rallies-against-thief`（权重 9 > 喊冤 7）；主阵容不挂（免搅 cry 金），`reputeSeed` 覆盖 dave 后自由跑。获知植怒不影响既有金轨迹（无 rally want 时仍选 cry）。
- **测**：SandboxSpec 臭名阈值/愤怒/harvest 控告 vs market 声援门禁；pickAction 优先声援；44 步 `sandboxReputeGolden`（dave 声援替代喊冤）。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名；未接线 Coerce/Blackmail（下一项候选）。

## v204 — Sandbox 站队胁迫招供（Coerce × factionStanding）

- **做了什么**：自定义 `Coercion`「squeeze」——触发为已 `factionStanding` 站队的磨坊成员；威胁要招供（`confessed`），违抗/站立威胁可烙印（`branded`）；惩罚核重视烙印。实践默认**未激活**（不 Insert `practice.millSqueeze`，免搅既有金轨迹）；`activateSqueeze` / `coerceSeed` 激活并把 `punishes-squeeze` / `fears-brand` 挂到 dave/bob。永久 `complied`：招供后可再胁迫但不可再买，二次威胁以烙印收场。
- **测**：SandboxSpec 逐步（威胁→招供→再胁→烙印）；wants pick；21 步 `sandboxCoerceGolden`。默认世界既有金轨迹仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v205 — Sandbox 教会异端 × 磨坊正义同场双压

- **做了什么**：新实践 `churchBobHeresy`（默认未激活）——教会对 **bob** 的听闻→审查→领袖放逐轨，与磨坊贼案共享 `exiled.bob`，形成同场竞速。欲望 `seeks-bob-heresy` / `punishes-bob-heretic`（权重 9 > eve 审查 8）+ 复用 `wants-exile-bob`；`activateChurchBob` / `dualPressureSeed` 激活并把牧师/gale 挂到 bob 异端正义。可测：harvest 窗内磨坊控告与教会审查 bob 交错并存；窗外磨坊放逐 vs 领袖放逐竞速（先到堵住后到）；权重优先 bob 审查压过 eve。44 步金轨迹钉磨坊先放逐、教会审查后等待。
- **测**：SandboxSpec 默认未激活 / 交错门禁+双向竞速 / 权重优先 / wants pick / 44 步 `sandboxDualPressureGolden`；既有 Sandbox 金仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v206 — Sandbox 教会异端 × 沉默债

- **做了什么**：新实践 `churchSilence`（默认激活，与磨坊沉默同形但异质）——异端向已 `regards.*.heretic` 的教会证人买 `church-favor` 封口；债权人可撕毁（`revoked`）。`churchHeresy` / `churchBobHeresy` 的审查动作加 `lacksOwes … church-favor` 门禁：买沉默堵住审查，撕债后翻转。债务内容与磨坊 `favor` 分离，免抢撕毁标签。欲望 `buys-church-silence` / `breaks-church-silence`；`churchSilenceSeed` 挂 eve/gale，静音磨坊噪声。
- **测**：SandboxSpec 逐步（买→堵审查→撕→审查开）；wants pick；43 步 `sandboxChurchSilenceGolden`（买→撕→审查→领袖放逐）。既有 Sandbox 金仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v207 — Sandbox 教会胁迫悔罪（Coerce × heretic 站队）

- **做了什么**：自定义 `Coercion`「inquisit」——触发为已 `factionStanding` 站队的**教会**成员；威胁要悔罪（`recanted`），违抗/站立威胁可烙异端印（`brandedHeretic`）。实践默认**未激活**；`activateInquisit` / `inquisitSeed` 与 `churchBobHeresy` 同开，牧师挂 `punishes-inquisit`，bob 挂 `fears-brand-heretic`。与异端轨真正交错：窗外胁→悔→再胁→烙印，harvest 仍可审查，窗外领袖放逐。
- **测**：SandboxSpec 逐步（胁→悔→再胁→烙→审查→放逐仍开）；wants pick；43 步 `sandboxInquisitGolden`。既有金仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：不合 main；不接线 Village `factionStanding`；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名。

## v208 — Village 接线 factionStanding（动金标准）

- **做了什么**：`Prax.Worlds.Village` 真接线 `factionStanding`（yu 拍板动金标准）。面包偷窃双重可观察：保留 `stole.Actor.loaf`（`standingUnless`/`notoriety` 村级脊骨）并加 `stole.Actor.carol`（摊位看守 = 人受害方，两变量模式喂 `factionStanding`）。公理加 `comrades` + `factionStanding "stole.Culprit.Victim" "oathbreaker"`——标签用 `oathbreaker` 而非 `thief`，使赎罪仍经 `standingUnless`/`atoned` 溶解村级贼站队，而磨坊共成员的派系冤屈不随补赎消失（Feud `feudbreaker` 习语）。种子主成员：carol/dana/gale/you → mill，bob → guild，eve → outsiders；t=0 不预植偷窃信念，免无意义搅动早期自由跑。
- **金标准**：`AnalysisTableSpec` `villagePin` 刷新 footprint/axiomHead（`member`/`allied`/`regards…oathbreaker`）；`VillageSpec` 新增三案钉磨坊目击站队、局外信念不派生、赎罪清 thief 留 oathbreaker。`GoldenDrive` 村庄轨迹**未改**（早期自由跑不发生偷窃，行为与旁白不变）。FactionSpec 村庄形夹具保留为 Spec-only 对照，注释改为「Village 已接线」。
- **测**：全量 `stack test --fast` **987/987** 绿（1828.11s）；`Worlds.Village` 52/52（含 v280 三案）；`AnalysisTable`/`GoldenDrive` village 绿。
- **明确未做**：不合 main；无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未堆 Condition has*/lacks* 叶子别名；Sandbox 未改。

## v209 — Coerce hasThreatened / hasDefied 叶子别名

- **做了什么**：`hasThreatened` = `isThreatened` 同体；`hasDefied` = `isDefied` 同体（对齐已有 `hasComplied`/`hasExtorted` 的 has* 命名）。
- **测**：CoerceSpec hasThreatened / hasDefied aliases。

## v210 — Host brandedOf / revokedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举烙印叶（`branded*` 前缀，含 `brandedHeretic`）与撕毁协议叶（`revoked.<creditor>.<debtor>` 任一侧）；CLI `prax branded`/`revoked`；`askChronicle` 加 `"branded of "`/`"revoked of "`；help 同步。
- **测**：HostSpec brandedOf / revokedOf；ChronicleSpec branded-of / revoked-of。

## v211 — Village oathbreaker 放逐（赎罪后派系冤屈仍有牙）

- **做了什么**：村庄实践加 `[Actor]: ostracize [T] as oathbreaker`——门禁于 `regardedAs … oathbreaker`，与村级 `thief`/`shun` 解耦。赎罪清 thief 站队并关闭 shun 后，磨坊目击仍可放逐；局外信念不派生站队故无放逐。**无**角色 want 匹配 `ostracized.*`（仅 Spec/玩家驱动），早期自由跑不偷窃 → `GoldenDrive`/`AnalysisTable` caresAbout 预期不变。
- **测**：VillageSpec v281 案（赎罪后 ostracize 开 / shun 闭 / 一击叶 / eve 负例）。全量 `stack test --fast` **992/992** 绿（1842.98s）；`GoldenDrive`/`AnalysisTable` village 绿。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；Sandbox 未改；未再堆其他 Condition has*/lacks*。

## v212 — Host confessedOf / recantedOf / ostracizedOf / exiledOf + CLI + Chronicle

- **做了什么**：闭合视图枚举招供叶（`confessed.<who>` 与 Village 形 `<who>.confessed.*`）、悔罪叶（`recanted.<who>`）、放逐叶（`ostracized.<a>.<t>` 任一侧）、流放叶（`exiled.<who>`）；CLI `prax confessed|recanted|ostracized|exiled`；`askChronicle` 加对应 `"… of "` 查询；help 同步。
- **测**：HostSpec / ChronicleSpec 四对偶。

## v213 — Debt hasRevoked / lacksRevoked；Sandbox 沉默门禁改用别名

- **做了什么**：`hasRevoked` / `lacksRevoked` 覆盖 `revoked.<creditor>.<debtor>`；`millSilence` / `churchSilence` 门禁由裸 `Not "revoked…"` 改为 `lacksRevoked`（语义同体）。
- **测**：DebtSpec hasRevoked / lacksRevoked duals；既有沉默弧回归。

## v214 — Sandbox 沉默×胁迫交叉 + 烙印游街（默认未激活）

- **做了什么**：Spec 钉沉默债堵住 ira 控告时 dave 胁迫仍开（交叉既有原语）。新实践 `millBrandParade`：已 `regards…thief` 的磨坊成员对 `branded.T` 可游街（`paraded.Actor.T`）；默认不 Insert practice；`activateParade` 激活；**无** want 匹配 `paraded.*`（免搅金轨迹）。
- **测**：SandboxSpec silence×squeeze；brand parade 门禁/一击/负例。既有 Sandbox 金仍绿。Village / GoldenDrive / Bar / Feud 金标准未动。全量 `stack test --fast` **997/997** 绿（1792.43s）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未再堆其他 Condition has*/lacks*；未动 Village 金标准。

## v215 — Host denouncedOf / censuredOf / paradedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举控告叶（`denounced.<a>.<t>` 任一侧）、审查叶（`censured.<a>.<t>`）、游街叶（`paraded.<a>.<t>`）；CLI `prax denounced|censured|paraded`；`askChronicle` 加对应 `"… of "`；help 同步。
- **测**：HostSpec / ChronicleSpec 三对偶。

## v216 — Coerce isBranded / lacksBranded / isBrandedHeretic / lacksBrandedHeretic

- **做了什么**：烙印 Condition 别名；Sandbox `millSqueeze`/`churchInquisit` 的 `coPunishWhen`/`coKernel`/恐惧 Want 与 `millBrandParade` 门禁改用别名（语义同体）。
- **测**：CoerceSpec branded duals；既有 coerce/inquisit/parade 回归。

## v217 — Sandbox churchBrandParade（默认未激活）

- **做了什么**：新实践 `churchBrandParade`：已 `regards…heretic` 的教会成员对 `brandedHeretic.T` 可游街（`paraded.Actor.T`）；默认不 Insert practice；`activateChurchParade` 激活；**无** want 匹配 `paraded.*`。
- **测**：SandboxSpec church brand parade 门禁/一击/负例。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v218 — Host criedOf / ralliedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举市集喊冤叶（`cried.<a>.<t>` 任一侧）、声援叶（`rallied.<a>.<t>`）；CLI `prax cried|rallied`；`askChronicle` 加 `"cried of "`/`"rallied of "`；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v219 — Host fledOf / reconciledOf / marriedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举叛逃叶（`fled.<who>`）、和解叶（`reconciled.<who>`）、婚入叶（`married.<a>.<b>` 任一侧）；CLI `prax fled|reconciled|married`；`askChronicle` 对应查询；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v220 — Sandbox 沉默×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉沉默债堵住 ira harvest 控告时，market 窗 `cry the theft` 仍开（`marketCry` 不读 owes；与控告门禁解耦）。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × market cry。Village / GoldenDrive / Bar / Feud 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未把 owes 接到 cry；未动 Village 金标准。

## v221 — Host eyedOf / confrontedOf / atonedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举目击疑心叶（`eyed.<a>.<t>`）、对质叶（`confronted.<a>.<t>`）、赎罪叶（`atoned.<who>`）；CLI `prax eyed|confronted|atoned`；`askChronicle` 对应 `"… of "`；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v222 — Sandbox 教会沉默×胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 `inquisitSeed` 下 bob 买牧师异端沉默债后：harvest `censure bob` 被 `lacksOwes` 堵住，牧师 `squeeze bob` 仍开（coerce 不读 owes）。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × inquisit。Village / GoldenDrive 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v223 — Host wrongedOf / hungryOf + CLI + Chronicle

- **做了什么**：闭合视图枚举冤屈叶（`wronged.<offender>.<victim>` 任一侧；Feud）与饥饿叶（`hungry.<who>`；Village）；CLI `prax wronged|hungry`；`askChronicle` 对应查询；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v224 — Sandbox 叛逃×胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 `coerceSeed` 下受害方 carol 叛逃溶解 dave 的 `regards…thief` 后 squeeze 关闭；和解回磨坊后站队与 squeeze 恢复。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × squeeze。Village / GoldenDrive / Feud 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village/Feud 金标准。

## v225 — Host shortTemperedOf / appetiteOf + CLI + Chronicle

- **做了什么**：闭合视图枚举暴脾气叶（`shortTempered.<who>`）与胃口叶（`appetite.<who>`；Village）；CLI `prax short-tempered|appetite`；`askChronicle` 对应查询；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v226 — Sandbox 烙印游街×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 brand→activateParade 后 market 窗内 cry 与 parade 互不阻挡：喊冤落 `cried` 后仍可游街；游街后 cry 已消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec parade × market cry。Village / GoldenDrive 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v227 — Host resentsOf + CLI + Chronicle

- **做了什么**：闭合视图枚举怨恨主体叶（`resents.<who>.<target>`；Feud 派生）；CLI `prax resents`；`askChronicle "resents of "`；help 同步。
- **测**：HostSpec / ChronicleSpec。

## v228 — Sandbox 叛逃×烙印游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 brand→activateParade 后受害方 carol 叛逃溶解 dave 的 `regards…thief`，parade 关闭；和解回磨坊后站队与 parade 恢复。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × parade。Village / GoldenDrive 金标准未动。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village/Feud 金标准。

## v229 — Host alliedOf + CLI + Chronicle

- **做了什么**：闭合视图枚举同盟叶（`allied.<a>.<b>` 任一侧；Feud）；CLI `prax allied`；`askChronicle "allied of "`；help 同步。
- **测**：HostSpec / ChronicleSpec（针对性；未跑全量）。

## v230 — Sandbox 沉默×烙印游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 brand→activateParade 后 bob 买 ira 沉默债：harvest 下 ira denounce 被 `lacksOwes` 堵住，dave parade 仍开（游街不读 owes）。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v231 — Coerce isParaded / lacksParaded 条件对偶

- **做了什么**：`isParaded`/`lacksParaded` 钉 `paraded.<actor>.<target>` Match/Not 对偶（对齐 brand parade 门禁）。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v232 — Sandbox 教会沉默×异端游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisit brand→activateChurchParade 后 bob 买牧师异端沉默债：harvest censure 被 `lacksOwes` 堵住，priest parade 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v233 — Coerce isCried / lacksCried 条件对偶

- **做了什么**：`isCried`/`lacksCried` 钉 `cried.<actor>.<target>` Match/Not 对偶（对齐 marketCry）。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v234 — Sandbox 叛逃×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉受害方 carol 叛逃溶解 dave 的 `regards…thief` 后 market cry 关闭；和解回磨坊后站队与 cry 恢复。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × market cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v235 — Coerce isDenounced / isRallied 条件对偶

- **做了什么**：`isDenounced`/`lacksDenounced`、`isRallied`/`lacksRallied` 钉对应 Match/Not 对偶。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v236 — Sandbox 教会游街×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisit brand→activateChurchParade 后 market 窗内 mill cry 与 church parade 互不阻挡。无新实践 / 无 want 改动。
- **测**：SandboxSpec church parade × market cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v237 — Coerce isCensured / isExiled 条件对偶

- **做了什么**：`isCensured`/`lacksCensured`（`censured.<a>.<t>`）、`isExiled`/`lacksExiled`（`exiled.<who>`）Match/Not 对偶。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v238 — Sandbox 沉默×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 reputeSeed 臭名+愤怒路径下 bob 买 ira 沉默债：harvest ira denounce 被 `lacksOwes` 堵住，market dave rally 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v239 — Host stallOf 货摊存货叶

- **做了什么**：`stallOf` 列出闭合视图中 `stall.<item>` 对象叶（Village 金轨迹叶形，对齐 `festivalsOf`）；CLI `prax stall <world>`。无实践 / 无 Village 金标准改动。
- **测**：HostSpec stallOf（针对性；未跑全量）。

## v240 — Sandbox 叛逃×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉受害方 carol 叛逃磨坊→公会后：磨坊 `regards.dave` 溶解（market cry 关），但公会已信同志（kyle+carol）重派生站队 → notoriety 仍在 → dave（仍愤怒）market rally 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v241 — Coerce isFled / isReconciled 条件对偶

- **做了什么**：`isFled`/`lacksFled`、`isReconciled`/`lacksReconciled` 钉 `fled.<who>` / `reconciled.<who>` Match/Not 对偶（对齐 millAllegiance）。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v242 — Sandbox 游街×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 brand→activateParade 与 reputeSeed 臭名路径并置后，market 窗内 mill parade 与 rally 互不阻挡（无共享 once-gate）。无新实践 / 无 want 改动。
- **测**：SandboxSpec parade × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v243 — Coerce isConfessed / isRecanted 条件对偶

- **做了什么**：`isConfessed`/`lacksConfessed`、`isRecanted`/`lacksRecanted` 钉招供/悔罪 unary Match/Not 对偶（对齐 millSqueeze / churchInquisit demand）。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v244 — Sandbox 教会游街×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisit brand→activateChurchParade 与 reputeSeed 臭名路径并置后，market 窗内 church parade 与 mill rally 互不阻挡。无新实践 / 无 want 改动。
- **测**：SandboxSpec church parade × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v245 — Coerce isMarried / isOstracized 条件对偶

- **做了什么**：`isMarried`/`lacksMarried`（`married.<a>.<b>`）、`isOstracized`/`lacksOstracized`（`ostracized.<a>.<t>`）Match/Not 对偶。无实践改动。
- **测**：CoerceSpec（针对性；未跑全量）。

## v246 — Sandbox 市集喊冤×声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 reputeSeed 臭名路径下 market 窗内 cry 与 rally 互不阻挡（无共享 once-gate）。无新实践 / 无 want 改动。
- **测**：SandboxSpec cry × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v247 — Coerce isAtoned / isHungry 条件对偶

- **做了什么**：`isAtoned`/`lacksAtoned`、`isHungry`/`lacksHungry` 钉 Village 赎罪/饥饿 unary Match/Not 对偶。无实践改动；未动 Village 金标准。
- **测**：CoerceSpec（针对性；未跑全量）。

## v248 — Sandbox 沉默×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 bob 买 ira 沉默债后 harvest ira denounce/exile 链被 `lacksOwes` 堵住，dave 仍可 denounce→exile。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v249 — Coerce isEyed / isConfronted 条件对偶

- **做了什么**：`isEyed`/`lacksEyed`、`isConfronted`/`lacksConfronted` 钉 Village 目击/对质 binary Match/Not 对偶。无实践改动；未动 Village 金标准。
- **测**：CoerceSpec（针对性；未跑全量）。

## v250 — Sandbox 教会沉默×磨坊放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 bob 买牧师异端沉默债后 harvest censure/banish 被堵住，dave 磨坊 denounce→exile 仍开（双轨独立）。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v251 — Coerce isWronged / isAllied 条件对偶

- **做了什么**：`isWronged`/`lacksWronged`、`isAllied`/`lacksAllied` 钉 Feud/Faction binary Match/Not 对偶。无实践改动；未动 Feud/Village 金标准。
- **测**：CoerceSpec（针对性；未跑全量）。

## v252 — Sandbox 胁迫×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 activateSqueeze + reputeSeed 臭名路径并置后，market 窗内 mill squeeze 与 rally 互不阻挡。无新实践 / 无 want 改动。
- **测**：SandboxSpec squeeze × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v253 — Coerce isResents / isShortTempered / isAppetite 条件对偶

- **做了什么**：`isResents`/`lacksResents`、`isShortTempered`/`lacksShortTempered`、`isAppetite`/`lacksAppetite` 钉 Feud/Village 叶 Match/Not 对偶。无实践改动；未动金标准。
- **测**：CoerceSpec（针对性；未跑全量）。

## v254 — Sandbox 婚入×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 已信但公会无站队；婚入磨坊后 regard 派生，market cry 打开（相对 harvest denounce 独立）。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v255 — Chronicle what is on the stall

- **做了什么**：`askChronicle` 增加 `"what is on the stall"`，列出 `stall.<item>` 基事实（对齐 Host `stallOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v256 — Sandbox 胁迫×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 activateSqueeze 后 market 窗内 mill squeeze 与 cry 互不阻挡。无新实践 / 无 want 改动。
- **测**：SandboxSpec squeeze × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v257 — Sandbox 教会胁迫×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisitSeed 下 priest squeeze 与 dave market cry 互不阻挡（教会 coerce 与磨坊市集轨独立）。无新实践 / 无 want 改动。
- **测**：SandboxSpec inquisit × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v258 — Chronicle what festivals

- **做了什么**：`askChronicle` 增加 `"what festivals"`，列出 `festival.*` 基事实（对齐 Host `festivalsOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v259 — Sandbox 教会胁迫×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisitSeed + 双人 learn 臭名路径下 priest squeeze 与 dave market rally 互不阻挡。无新实践 / 无 want 改动。
- **测**：SandboxSpec inquisit × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v260 — Chronicle holding of / carrying of

- **做了什么**：`askChronicle` 增加 `"holding of "` / `"carrying of "`，列出 `holding.<who>.*` / `carrying.<who>.*`（对齐 Host `holdingOf`/`carryingOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v261 — Sandbox 婚入×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入磨坊后派生 regard，与 dave learn 凑齐臭名，market rally 打开（婚入站队与声援轨衔接）。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v262 — Chronicle threatened of / shunned of

- **做了什么**：`askChronicle` 增加 `"threatened of "` / `"shunned of "`（对齐 Host `threatenedOf`/`shunnedOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v263 — Sandbox 次级归属×胁迫负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate 磨坊、无 primary member → 无 regard → millSqueeze 对 kyle 关闭，dave（primary）仍可 squeeze。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v264 — Chronicle locations of / demanded of

- **做了什么**：`askChronicle` 增加 `"locations of "` / `"demanded of "`（对齐 Host `locationsOf`/`demandedOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v265 — Sandbox 胁迫×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 activateSqueeze 后 harvest denounce→exile 与 millSqueeze 互不阻挡（先 squeeze 仍可 exile）。无新实践 / 无 want 改动。
- **测**：SandboxSpec squeeze × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v266 — Chronicle extorted of / complied of / defied of

- **做了什么**：`askChronicle` 增加 `"extorted of "` / `"complied of "` / `"defied of "`（对齐 Host `extortedOf`/`compliedOf`/`defiedOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v267 — Sandbox 婚入×胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 已信但公会无站队时 squeeze 关闭；婚入磨坊后 regard 派生，activateSqueeze 下 fran 可 squeeze。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v268 — Chronicle obligations of / breaches of

- **做了什么**：`askChronicle` 增加 `"obligations of "` / `"breaches of "`（对齐 Host `obligationsOf`/`breachesOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v269 — Sandbox 教会胁迫×磨坊放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisitSeed 下 priest squeeze 与 dave denounce→exile 互不阻挡（先 squeeze 仍可 exile）。无新实践 / 无 want 改动。
- **测**：SandboxSpec inquisit × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v270 — Chronicle lies of / chatted with / traits of

- **做了什么**：`askChronicle` 增加 `"lies of "` / `"chatted with "` / `"traits of "`（对齐 Host `liesOf`/`chattedWithOf`/`traitsOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v271 — Sandbox 教会沉默×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 bob 买牧师异端沉默债后 harvest censure 被堵住，dave market cry 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v272 — Chronicle bonds of / esteemed of / scorned of

- **做了什么**：`askChronicle` 增加 `"bonds of "` / `"esteemed of "` / `"scorned of "`（对齐 Host `bondsOf`/`esteemedOf`/`scornedOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v273 — Sandbox 游街×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 brand→activateParade 后 harvest denounce→exile 与 parade 互不阻挡（先 parade 仍可 exile）。无新实践 / 无 want 改动。
- **测**：SandboxSpec parade × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v274 — Chronicle beliefs of / projects of

- **做了什么**：`askChronicle` 增加 `"beliefs of "` / `"projects of "`（对齐 Host `beliefsOf`/`projectsOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v275 — Sandbox 教会沉默×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 bob 买牧师异端沉默债后 harvest censure 被堵住，dave market rally 仍开（臭名路径）。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v276 — Chronicle kin of

- **做了什么**：`askChronicle` 增加 `"kin of "`，列出 married/parent/sibling/inLaw/grandparent 任一侧（对齐 Host `kinOf`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v277 — Sandbox 婚入×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入磨坊后 regard 派生，harvest denounce→exile 打开。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v278 — Chronicle notorious of

- **做了什么**：`askChronicle` 增加 `"notorious of "`，列出 `notorious.<who>.*`（对齐 Host `notoriousOf`；与 `"what is notorious"` 钩子摘要互补）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v279 — Sandbox 附属×集会负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate 磨坊、主籍公会 → 无 regard/怒 → 市集 rally 关闭；dave（主籍+臭名路径）可 rally。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v280 — Sandbox 市集喊冤×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉市集 cry 与 harvest denounce→exile 无共享 once-gate：先 cry，下一轮 harvest 仍可 denounce/exile。无新实践 / 无 want 改动。
- **测**：SandboxSpec cry × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v281 — Sandbox 附属×游街负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate 磨坊 → 无 regard → parade 关闭；dave 烙印路径可 parade。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v282 — Sandbox 附属×放逐负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate → harvest denounce/exile 关闭；dave 可完成放逐。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v283 — Sandbox 婚入×游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入磨坊后 regard 派生，烙印路径下 parade 打开。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v284 — Sandbox 教会胁迫×磨坊游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisitSeed 教会 squeeze 与磨坊 brand→parade 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec inquisit × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v285 — Sandbox 教会沉默×磨坊胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 bob 买神父沉默后 harvest censure 关闭，dave 磨坊 squeeze 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec church silence × squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v286 — Sandbox 附属×市集喊冤负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate → 市集 cry 关闭；dave 可喊冤。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v287 — Sandbox 叛逃×放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 carol 叛逃溶解 regard → denounce/exile 关闭；回归后恢复并完成放逐。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v288 — Sandbox 教会游街×磨坊放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉异端 brand→church parade 与磨坊 denounce→exile 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec church parade × exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v289 — Sandbox 教会游街×磨坊胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉异端 church parade 与磨坊 squeeze 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec church parade × squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v290 — Sandbox 教会胁迫×磨坊胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 inquisit 与 mill squeeze 双轨同时可开、互不消耗 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec inquisit × squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v291 — Sandbox 叛逃×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 carol 叛逃关闭磨坊 squeeze，教会 inquisit squeeze 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v292 — Sandbox 叛逃×教会游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 carol 叛逃关闭磨坊 parade，异端 church parade 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × church parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v293 — Chronicle regards toward

- **做了什么**：`askChronicle` 增加 `"regards toward "`，列出指向目标的 `regards.*.target.*`（对齐 Host `regardsToward`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v294 — Chronicle what factions

- **做了什么**：`askChronicle` 增加 `"what factions"`，列出 member/affiliate/leads 上的派系名（对齐 Host `factionsNamed`）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v295 — Sandbox 磨坊沉默×教会游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 ira 沉默债挡 denounce，异端 church parade 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × church parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v296 — Sandbox 磨坊沉默×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 ira 沉默债挡 denounce，priest inquisit squeeze 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v297 — Sandbox 婚入×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入打开磨坊 squeeze，priest inquisit squeeze 并行不互相消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v298 — Sandbox 市集喊冤×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉市集 cry 与 inquisit squeeze 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec cry × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v299 — Sandbox 市集声援×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 market rally 与 inquisit squeeze 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec rally × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v300 — Sandbox 婚入×教会游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入打开磨坊 regard，异端 church parade 仍开且可完成。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × church parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v301 — Sandbox 控告×游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 harvest denounce 与 brand parade 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec denounce × parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v302 — Sandbox 放逐×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill exile 窗内 inquisit squeeze 仍开，互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec exile × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v303 — Chronicle members/affiliates/leads 读闭合视图

- **做了什么**：`members of` / `affiliates of` / `leads of` 改为 `readView`（对齐 Host membersOf/affiliatesOf/leadersOf）。无实践 / 无 Village 金标准改动。
- **测**：ChronicleSpec 既有 leads/affiliates/members 用例（针对性；未跑全量）。

## v304 — Sandbox 磨坊沉默×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 ira 沉默债挡 mill denounce/exile，priest 异端 censure→exile 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec silence × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v305 — Sandbox 磨坊游街×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill brand parade 与 priest censure→banish 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec parade × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v306 — Sandbox 市集喊冤×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉市集 cry 后下一轮 harvest 教会 censure→banish 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec cry × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v307 — Sandbox 磨坊胁迫×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill squeeze 与 priest censure→banish 无共享 once-gate。无新实践 / 无 want 改动。
- **测**：SandboxSpec squeeze × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v308 — Sandbox 市集声援×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 market rally 后下一轮 harvest 教会 censure→banish 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec rally × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v309 — Sandbox 婚入×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入打开磨坊 regard/denounce，priest censure→banish 并行。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v310 — Sandbox 附属×教会轨负例（钉既有门禁）

- **做了什么**：Spec 钉 kyle 仅 affiliate 磨坊 → 无教会 standing → censure/banish 关闭；priest 可完成放逐。无新实践 / 无 want 改动。
- **测**：SandboxSpec affiliate × church（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v311 — Chronicle 读视图对齐 feelings/mood/arc/age/festivals/holding/carrying/shunned/locations

- **做了什么**：九条 askChronicle 臂改读 `readView`，对齐 Host *Of；Spec 钉 festivals/holding/carrying/shunned/locations/feelings 与 Host 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v312 — Sandbox 叛逃×教会放逐 + 附属×审讯负例（钉既有门禁）

- **做了什么**：Spec 钉 carol flee 溶磨坊 regard 而 priest banish 并行；钉 kyle 仅 affiliate 无教会 squeeze。无新实践 / 无 want 改动。
- **测**：SandboxSpec defection × church exile、affiliate × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v313 — Chronicle 余下 Host *Of 读视图对齐

- **做了什么**：四十余条 askChronicle 臂（debts/branded/…/kin/stall 等）改读 `readView`，对齐 Host *Of；Spec 钉 obligations/breaches/debts/threatened/stall/kin 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v314 — Sandbox 附属×教会游街 + Debt/Coerce 边角世界求值

- **做了什么**：Spec 钉 kyle 无教会 parade、harvest 无 denounce/censure；Debt Spec 钉 owes/lacksOwes/hasRevoked 世界求值；Coerce Spec 钉 isThreatened/lacksThreatened 与 isExiled/isParaded 世界求值。无新实践 / 无 want 改动。
- **测**：SandboxSpec、DebtSpec、CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v315 — Sandbox 婚入×教会沉默 + 叛逃×教会沉默交叉（钉既有门禁）

- **做了什么**：Spec 钉 fran 婚入打开磨坊 denounce 而 priest 债挡 censure；钉 carol flee 关磨坊、priest 债挡 censure，return 只恢复磨坊。无新实践 / 无 want 改动。
- **测**：SandboxSpec wed × church silence、defection × church silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v316 — Chronicle branded/exiled/denounced 对偶 + Coerce denounce/censure 世界求值

- **做了什么**：Spec 钉 branded/exiled/denounced 与 Host 对偶、mood/arc 短语形；Coerce Spec 钉 isDenounced/isCensured 世界求值。无新实践 / 无 want 改动。
- **测**：ChronicleSpec、CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v317 — Sandbox 游街×教会沉默 + 检举×教会放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill parade 与 priest 债挡 censure 并行；钉 dave denounce/exile 与 priest banish 并行。无新实践 / 无 want 改动。
- **测**：SandboxSpec parade × church silence、denounce × church exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v318 — Coerce married/ostracized/confessed + Debt isDemanded 世界求值

- **做了什么**：Coerce Spec 钉 isMarried/isOstracized/isConfessed 世界求值；Debt Spec 钉 isDemanded 在 demand 动作后求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec、DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v319 — Sandbox 市集喊冤/声援×教会沉默交叉（钉既有门禁）

- **做了什么**：Spec 钉 market cry/rally 与 priest 债挡 censure 并行。无新实践 / 无 want 改动。
- **测**：SandboxSpec cry × church silence、rally × church silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v320 — Chronicle lies/traits/chatted/esteemed/scorned 与 Host 对偶

- **做了什么**：Spec 钉 lies/traits/chatted/esteemed/scorned 与 Host *Of 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v321 — Sandbox 胁迫×教会沉默 + 附属×教会沉默（钉既有门禁）

- **做了什么**：Spec 钉 mill squeeze 与 priest 债挡 censure 并行；钉 kyle 无 censure 且 priest 债挡. 无新实践 / 无 want 改动。
- **测**：SandboxSpec squeeze × church silence、affiliate × church silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v322 — Coerce recanted/fled/hungry/rallied + Chronicle beliefs/projects/bonds 对偶

- **做了什么**：Coerce Spec 钉 isRecanted/isFled/isHungry/isRallied 世界求值；Chronicle Spec 钉 beliefs/projects/bonds 与 Host 对偶。无新实践 / 无 want 改动。
- **测**：CoerceSpec、ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v323 — Sandbox 放逐×教会沉默 + 婚入×磨坊沉默（钉既有门禁）

- **做了什么**：Spec 钉 dave exile 与 priest 债挡 banish 并行；钉 fran 婚入 denounce 开而 ira 债挡. 无新实践 / 无 want 改动。
- **测**：SandboxSpec exile × church silence、wed × silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v324 — Chronicle extorted/complied/defied 对偶 + Coerce cried/eyed/confronted/wronged

- **做了什么**：Chronicle Spec 钉 extorted/complied/defied 与 Host 对偶；Coerce Spec 钉 isCried/isEyed/isConfronted/isWronged 世界求值。无新实践 / 无 want 改动。
- **测**：ChronicleSpec、CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v325 — Coerce allied/resents/atoned/reconciled/appetite/shortTempered 世界求值

- **做了什么**：Coerce Spec 钉 isAllied/isResents/isAtoned/isReconciled/isAppetite/isShortTempered 世界求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v326 — Chronicle 更多 Host 对偶 + Sandbox 叛逃×磨坊沉默

- **做了什么**：Chronicle Spec 钉 revoked/confessed/censured/paraded/cried/rallied 与 Host 对偶；Sandbox Spec 钉 carol flee×ira 债交叉（return 只恢复磨坊）。无新实践 / 无 want 改动。
- **测**：ChronicleSpec、SandboxSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v327 — Chronicle fled/reconciled/married/ostracized/atoned/hungry 对偶

- **做了什么**：Spec 钉六条 askChronicle 臂与 Host *Of 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v328 — Sandbox 附属×磨坊沉默 + Debt neverOwed/everDemanded 世界求值

- **做了什么**：Spec 钉 kyle 无 denounce 且 ira 债挡；Debt Spec 钉 neverOwed/everDemanded 世界求值。无新实践 / 无 want 改动。
- **测**：SandboxSpec、DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v329 — Coerce ever*/never* 威胁/违抗/服从/勒索世界求值

- **做了什么**：Coerce Spec 钉 everThreatened/neverThreatened/everExtorted、everDefied/neverDefied、everComplied/neverComplied 在 threaten/defy/favor 动作后与净世界上的 satisfies 求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v330 — Coerce branded 世界求值 + Debt everOwed/neverDemanded/hasCreditorClaim

- **做了什么**：Coerce Spec 钉 isBranded/lacksBranded/isBrandedHeretic Insert 世界求值；Debt Spec 钉 everOwed/neverDemanded/hasCreditorClaim/lacksCreditorClaim 世界求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec、DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v331 — Sandbox 控告×教会沉默交叉（钉既有门禁）

- **做了什么**：Spec 钉 dave harvest denounce 完成而 priest 债挡 censure。无新实践 / 无 want 改动。
- **测**：SandboxSpec denounce × church silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v332 — Sandbox 控告×教会胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill denounce 与 priest inquisit squeeze 并行、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec denounce × inquisit（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v333 — Sandbox 控告×教会游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 mill denounce 与 priest heretic parade 并行、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec denounce × church parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v334 — Sandbox 检举×磨坊沉默交叉（钉既有门禁）

- **做了什么**：Spec 钉 priest censure 开而 ira 债挡 mill denounce。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × mill silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v335 — Chronicle eyed/confronted/wronged/recanted 对偶

- **做了什么**：Spec 钉四条 askChronicle 臂与 Host *Of 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v336 — Chronicle shortTempered/appetite 对偶

- **做了什么**：Spec 钉 shortTempered/appetite 两条 askChronicle 臂与 Host *Of 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v337 — Chronicle resents/allied 对偶

- **做了什么**：Spec 钉 resents/allied 两条 askChronicle 臂与 Host *Of 对偶（allied 含任一侧）。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v338 — Chronicle demanded/notorious/regardsToward/factionsNamed 对偶

- **做了什么**：Spec 钉 demanded/notorious/regards toward/what factions 与 Host *Of 对偶。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v339 — Coerce hasComplied/hasDefied/hasExtorted 世界求值

- **做了什么**：Coerce Spec 钉 hasComplied/lacksComplied、isDefied/hasDefied/lacksDefied 在 favor/defy 动作后，以及 hasExtorted/lacksExtorted/hasThreatened 在 threaten 后的 satisfies 求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v340 — Debt isOwed/hasOwed/hasOwes/hasDemanded 世界求值

- **做了什么**：Debt Spec 钉 isOwed/hasOwed/hasOwes 在 owe 世界上、hasDemanded 在 demand 动作后、以及 everOwed 在空世界上的 fails。无新实践 / 无 want 改动。
- **测**：DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v341 — Sandbox 检举×磨坊胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 priest censure 与 dave mill squeeze 并行、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × mill squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v342 — Sandbox 检举×磨坊游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 priest censure 与 dave brand parade 并行、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × mill parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v343 — Sandbox 检举×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 harvest censure 后 market cry 仍开、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v344 — Sandbox 检举×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 harvest censure 后 market rally 仍开、互不消耗。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v345 — Chronicle members/affiliates/leads 对偶 Host 名表

- **做了什么**：Spec 钉 members/affiliates/leads：Host *Of 返回裸名，askChronicle 短语化。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v346 — Chronicle age/regards-of 对偶 Host 原叶/短语

- **做了什么**：Spec 钉 age（agesOf 原叶 vs 短语）与 regards of（regardsToward 原叶 vs RegardHook 观察者短语）。无新实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v347 — Debt settle 清偿后 isOwed/everOwed/hasCreditorClaim 世界求值

- **做了什么**：Debt Spec 钉 settle 后 isOwed/everOwed/hasCreditorClaim 失败，以及 lacksCreditorClaim/neverOwed 成立。无新实践 / 无 want 改动。
- **测**：DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v348 — Deceit liedTo/hasLied/everLied 世界求值

- **做了什么**：Deceit Spec 钉 whisper 后 liedTo/hasLied/everLied 与净世界上 neverLied/lacksLied 的 satisfies 求值。无新实践 / 无 want 改动。
- **测**：DeceitSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v349 — Witness saw/hasSaw/everSaw 世界求值

- **做了什么**：Witness Spec 钉 wave 后 bea 的 saw/hasSaw/everSaw，以及净世界/缺席 cal 的 neverSaw/lacksSaw。无新实践 / 无 want 改动。
- **测**：WitnessSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v350 — Emotion hasFeeling/everFeeling/hasMood 世界求值

- **做了什么**：Emotion Spec 钉 feel/feelToward/setMood 世界上 hasFeeling/everFeeling/hasFeelingToward/everFeelingToward/hasInMood/hasMood 与净世界 lacks*/never*。无新实践 / 无 want 改动。
- **测**：EmotionSpec（针对性；未跑全量）。

## v351 — Sandbox 检举×磨坊放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉先 censure 后 mill denounce→exile，与 priest banish 并行开口。无新实践 / 无 want 改动。
- **测**：SandboxSpec censure × mill exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v352 — Sandbox 异端沉默×磨坊控告交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale church-favor 债挡 censure，dave mill denounce 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill denounce（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v353 — Sandbox 异端沉默×市集喊冤交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale 债挡 censure，dave market cry 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill cry（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v354 — Sandbox 异端沉默×磨坊胁迫交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale 债挡 censure，dave mill squeeze 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill squeeze（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v355 — Host siblingsOf + CLI prax siblings

- **做了什么**：闭合视图枚举 `sibling.<who>.*`（主体侧，对齐 Chronicle `siblings of`）；CLI `prax siblings`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec siblingsOf（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v356 — Chronicle siblings 对偶 Host siblingsOf + CLI explain

- **做了什么**：Spec 钉 siblings of（siblingsOf 原叶 vs 短语）；CLI `prax explain` 薄封 `explainActor`。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v357 — Rumor heard/hasHeard/everHeard 世界求值

- **做了什么**：Rumor Spec 钉 tell 后 heard/hasHeard/heardFrom/hasHeardFrom/everHeard 与净世界上 neverHeard/lacksHeard。无新实践 / 无 want 改动。
- **测**：RumorSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v358 — Persona hasTrait/everTrait 世界求值

- **做了什么**：Persona Spec 钉 Insert trait 后 hasTrait/everTrait 与净世界上 neverTrait/lacksTrait。无新实践 / 无 want 改动。
- **测**：PersonaSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v359 — Faction isMember/affiliates/isLeader/regardsAs 世界求值

- **做了什么**：Faction Spec 钉 joins/affiliate/appointLeader/regards Insert 世界上 isMember/affiliates/isLeader/regardsAs 及 ever*/never*/lacks*。无新实践 / 无 want 改动。
- **测**：FactionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v360 — Repute isNotorious/hasEsteemed/hasScorned 世界求值

- **做了什么**：Repute Spec 钉 Insert notorious/esteemed/scorned/regards 世界上 isNotorious/hasEsteemed/hasScorned/regardedAs 及 ever*/lacks*。无新实践 / 无 want 改动。
- **测**：ReputeSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v361 — Kin isChildOf/isMarriedTo/ever* 世界求值

- **做了什么**：Kin Spec 钉 kinWorld 上 isChildOf/isParentOf/isSiblingOf/isMarriedTo 与 everMarried/everParent/everSibling，以及空世界上 never*。无新实践 / 无 want 改动。
- **测**：KinSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v362 — Confession hasMark/isAbsolved 世界求值

- **做了什么**：Confession Spec 钉 Insert mark/defeater 后 hasMark/everMarked/isAbsolved/everAbsolved 与净世界上 neverMarked/lacksAbsolved。无新实践 / 无 want 改动。
- **测**：ConfessionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v363 — Conversation hasChattedWith/everChatted 世界求值

- **做了什么**：Conversation Spec 钉 Insert chattedWith 后 hasChattedWith/everChattedWith/everChatted 与净世界上 neverChatted/lacksChattedWith。无新实践 / 无 want 改动。
- **测**：ConversationSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v364 — Deontic hasObliged/hasObligations 世界求值

- **做了什么**：Deontic Spec 钉 oblige 后 isObliged/hasObliged/hasObligations/everObliged，以及 discharge 后 lacksObligations/neverObliged。无新实践 / 无 want 改动。
- **测**：DeonticSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v365 — Host parentsOf/childrenOf + CLI

- **做了什么**：闭合视图枚举 `parent.<p>.<who>` / `parent.<who>.<c>`；CLI `prax parents`/`children`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v366 — Chronicle parents/children of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"parents of "` / `"children of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v367 — Sandbox 异端沉默×磨坊游街交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale 债挡 censure，dave brand parade 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill parade（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v368 — Sandbox 异端沉默×市集声援交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale 债挡 censure，dave market rally 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill rally（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v369 — Sandbox 异端沉默×磨坊放逐交叉（钉既有门禁）

- **做了什么**：Spec 钉 gale 债挡 censure，dave denounce→exile 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec heresy silence × mill exile（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v370 — Sandbox 双沉默轨独立（磨坊×异端）（钉既有门禁）

- **做了什么**：Spec 钉 ira favor 与 gale church-favor 双债并存，dave mill denounce 仍开。无新实践 / 无 want 改动。
- **测**：SandboxSpec dual silence（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v371 — Host grandparentsOf/grandchildrenOf/inLawsOf + CLI

- **做了什么**：闭合视图枚举 `grandparent.<g>.<who>` / `grandparent.<who>.<c>` / `inLaw.<x>.<who>`；CLI `prax grandparents`/`grandchildren`/`in-laws`；补 siblings/parents/children/explain help。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v372 — Chronicle grandparents/grandchildren/in-laws of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"grandparents of "` / `"grandchildren of "` / `"in-laws of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v373 — Arc arcIs/hasArc/everArc 世界求值

- **做了什么**：Arc Spec 钉 enterArc/leaveArc 世界上 arcIs/hasArcIs/hasArc/everArc 与净世界上 neverArc/lacksArc。无新实践 / 无 want 改动。
- **测**：ArcSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v374 — Beliefs believesThat/holdsBelief/everBelieves 世界求值

- **做了什么**：Beliefs Spec 钉 believe 世界上 believesThat/holdsBelief/everBelieves/hasBelief 与净世界上 neverBelieves/doubts。无新实践 / 无 want 改动。
- **测**：BeliefsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v375 — Project isCrewOf/hasCompletedPart/everCrew 世界求值

- **做了什么**：Project Spec 钉 Insert crew/did 世界上 isCrewOf/hasCompletedPart/everCrew/everCompletedPart 与净世界上 never*。无新实践 / 无 want 改动。
- **测**：ProjectSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v376 — Reactions violationOf/everViolated 世界求值

- **做了什么**：Reactions Spec 钉 markViolation 世界上 violationOf/hasViolation/everViolated/everBreach 与净世界上 neverViolated/noViolation。无新实践 / 无 want 改动。
- **测**：ReactionsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v377 — Schedule duringFestival/hasFestival 世界求值

- **做了什么**：Schedule Spec 钉 Insert festival 叶后 duringFestival/hasFestival 与净世界上 outsideFestival/lacksFestival。无新实践 / 无 want 改动。
- **测**：ScheduleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v378 — Sight lastKnownAt/knownWhere 世界求值

- **做了什么**：Sight Spec 钉 believes.at Insert 世界上 lastKnownAt/knownWhere/hasKnownWhere 与净世界上 unknownWhere/lacksKnownWhere。无新实践 / 无 want 改动。
- **测**：SightSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v379 — Core hasBond/everBond 世界求值

- **做了什么**：Core Spec 钉 setBond 世界上 hasBond/everBond（含对称叶）与净世界上 neverBond/lacksBond。无新实践 / 无 want 改动。
- **测**：CoreSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v380 — Conversation talkingWith 世界求值

- **做了什么**：Conversation Spec 钉 beginConversation 世界上 talkingWith（规范化序路径）。无新实践 / 无 want 改动。
- **测**：ConversationSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v381 — Kin everInLaw/isInLawOf 世界求值

- **做了什么**：Kin Spec 钉 weddedWorld readView 上 isInLawOf/hasInLawOf/everInLaw 与净世界上 neverInLaw。无新实践 / 无 want 改动。
- **测**：KinSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v382 — Sandbox 烙印游街 want 词汇（磨坊）

- **做了什么**：`sandboxDesires` 增 `parades-branded-thief`（Match `paraded.Owner.bob`，权重 10）；导出 `paradeDesireName`。主阵容默认不挂（免搅金轨迹）；Spec 覆盖后 `pickAction` 在 brand 后自选游街。
- **测**：SandboxSpec wants: paradeSeed dave parades after brand；cast 默认无挂 + 词汇注册。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未默认激活 millBrandParade。

## v383 — Sandbox 异端烙印游街 want 词汇（教会）

- **做了什么**：`sandboxDesires` 增 `parades-branded-heretic`（Match `paraded.Owner.bob`，权重 10，对齐 inquisit 轨）；导出 `churchParadeDesireName`。主阵容默认不挂；Spec 覆盖后 priest 在 heretic brand 后自选游街。
- **测**：SandboxSpec wants: churchParadeSeed priest parades after heretic brand。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未默认激活 churchBrandParade。

## v384 — Host spousesOf + CLI

- **做了什么**：闭合视图枚举 `married.<who>.*`（主体侧，对齐 Chronicle `spouses of`）；CLI `prax spouses`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v385 — Chronicle spouses of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"spouses of "`（对齐 Host spousesOf）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v386 — Host creditorsOf/debtorsOf + CLI

- **做了什么**：闭合视图枚举 `debt.*.<who>.*` / `debt.<who>.*.*`；CLI `prax creditors`/`debtors`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v387 — Chronicle creditors/debtors of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"creditors of "` / `"debtors of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v388 — Emotion everMood/inMood/feelingToward 世界求值

- **做了什么**：Emotion Spec 钉 setMood/feelToward 世界上 everMood/inMood/feelingToward 与净世界上 neverMood。无新实践 / 无 want 改动。
- **测**：EmotionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v389 — Reactions reactionActive 世界求值

- **做了什么**：Reactions Spec 钉 spawnReaction/endReaction 世界上 reactionActive。无新实践 / 无 want 改动。
- **测**：ReactionsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v390 — Faction hasLeader/everAffiliate/lacks* 世界求值补全

- **做了什么**：Faction Spec 在既有世界求值用例上补 hasLeader/everAffiliate/hasRegardAs 与 lacksLeader/lacksAffiliate/lacksRegard。无新实践 / 无 want 改动。
- **测**：FactionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v391 — Repute hasRegardedAs 世界求值

- **做了什么**：Repute Spec 钉 Insert regards 世界上 hasRegardedAs。无新实践 / 无 want 改动。
- **测**：ReputeSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v392 — Coerce lacksAtoned/lacksEyed/lacksFled 等对偶世界求值

- **做了什么**：Coerce Spec 钉净世界与 Insert 社会标记世界上 lacksAtoned/lacksEyed/lacksFled/lacksRecanted/lacksConfronted/lacksWronged/lacksResents/lacksReconciled/lacksHungry/lacksOstracized/lacksShortTempered。无新实践 / 无 want 改动。
- **测**：CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v393 — CLI view/facts/available/living matching surfaces

- **做了什么**：CLI `prax view`/`facts`/`available`/`living` 薄封 `queryViewMatching`/`queryMatching`/`availableMatching`/`livingMatching`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v394 — Sandbox 无游街 want 时不自选游街（钉既有门禁）

- **做了什么**：Spec 钉 brand + activateParade 后 dave 仅挂 millCry（无 `parades-branded-thief`）时 `pickAction` 不选 parade。无新实践 / 无 want 改动。
- **测**：SandboxSpec wants: without paradeDesire dave does not pick parade after brand。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v395 — Sandbox 放逐权重压过游街 want（钉既有门禁）

- **做了什么**：Spec 钉 denounce 后窗外 dave 同挂 `wants-exile-bob`(12) 与 `parades-branded-thief`(10) 时优先 exile。无新实践 / 无 want 改动。
- **测**：SandboxSpec wants: exile weight beats parade when both open。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v396 — Kin lacksChildOf/lacksSiblingOf/ageAtLeast 世界求值

- **做了什么**：Kin Spec 钉净世界上 lacksChildOf/lacksSiblingOf 与 kinWorld 上对偶失败/hasParentOf/hasSiblingOf；setAge 世界上 ageAtLeast。无新实践 / 无 want 改动。
- **测**：KinSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v397 — Core scoreAtLeast 世界求值

- **做了什么**：Core Spec 钉 adjustScore 世界上 scoreAtLeast（含阈值下界失败）。无新实践 / 无 want 改动。
- **测**：CoreSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v398 — Emotion intensityAtLeast/lacksMood 世界求值

- **做了什么**：Emotion Spec 钉 feelAt/feelTowardAt 世界上 intensityAtLeast/intensityTowardAtLeast 与净世界上 lacksMood（via satisfies）。无新实践 / 无 want 改动。
- **测**：EmotionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v399 — Conversation onTopic/isSpeaker/isListener 世界求值

- **做了什么**：Conversation Spec 钉 beginConversation 世界上 onTopic/hasTopic/isSpeaker/isListener/offTopic/lacksSpeaker/lacksListener（A/B/Actor 绑定）。无新实践 / 无 want 改动。
- **测**：ConversationSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v400 — Host demandersOf/demandeesOf + CLI

- **做了什么**：闭合视图枚举 `demanded.*.<who>.*` / `demanded.<who>.*.*`；CLI `prax demanders`/`demandees`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v401 — Chronicle demanders/demandees of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"demanders of "` / `"demandees of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v402 — Sandbox 无教会游街 want 时不自选游街（钉既有门禁）

- **做了什么**：Spec 钉 heretic brand + activateChurchParade 后 priest 仅挂 bobHeresyJustice（无 `parades-branded-heretic`）时 `pickAction` 不选 parade。无新实践 / 无 want 改动。
- **测**：SandboxSpec wants: without churchParadeDesire priest does not pick parade。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v403 — Sandbox 放逐权重压过教会游街 want（钉既有门禁）

- **做了什么**：Spec 钉 censure 后牧师同挂 `wants-exile-bob`(12) 与 `parades-branded-heretic`(10) 时优先 exile/banish。无新实践 / 无 want 改动。
- **测**：SandboxSpec wants: bob exile weight beats church parade when both open。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v404 — Confession hasAbsolved/neverAbsolved 对偶

- **做了什么**：Confession 增加 hasAbsolved/neverAbsolved（对齐 has*/never*）；Spec 钉结构别名与 Insert 世界求值。无新实践 / 无 want 改动。
- **测**：ConfessionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v405 — Beliefs disbelievesThat 异值世界求值

- **做了什么**：Beliefs Spec 在 believe 世界上补钉 disbelievesThat 对异值成立。无新实践 / 无 want 改动。
- **测**：BeliefsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v406 — Deontic inBreach/fulfilled 世界求值

- **做了什么**：Deontic Spec 钉 breach/obliged+content 世界上 inBreach/fulfilled。无新实践 / 无 want 改动。
- **测**：DeonticSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v407 — Sandbox 市集声援/喊冤 want 名导出（钉既有门禁）

- **做了什么**：导出 `rallyDesireName`/`cryDesireName`；`sandboxDesires`/`millCry`/`iraCry` 改用常量。主阵容默认仍不挂 rally（免搅 cry 金轨迹）。
- **测**：SandboxSpec wants: rallyDesire weight beats cry；vocab 断言。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v408 — Sandbox 无声援/无喊冤 want 时不自选（钉既有门禁）

- **做了什么**：Spec 钉 market 门开时仅 millCry（无 rally）不选 rally 而选 cry；仅 millJustice（无 cry）不选 cry。无新实践。
- **测**：SandboxSpec wants: without rallyDesire / without cryDesire。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v409 — Host threateners/threatenees/extorters/extortees + CLI

- **做了什么**：闭合视图枚举 `threatened.*.*.<who>` / `threatened.*.<who>.*` 与 `*.extorted.<who>.*` / `<who>.extorted.*.*`；CLI `prax threateners`/`threatenees`/`extorters`/`extortees`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v410 — Chronicle threateners/threatenees/extorters/extortees of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"threateners of "` / `"threatenees of "` / `"extorters of "` / `"extortees of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v411 — Sandbox 无胁迫 want 时不自选 squeeze（钉既有门禁）

- **做了什么**：Spec 钉 activateSqueeze 后门开但 dave 仅 millJustice 时不选 squeeze；activateInquisit+hear 后门开但 priest 仅 bobHeresyJustice 时不选教会 squeeze。无新实践。
- **测**：SandboxSpec wants: without squeezeDesire / without inquisitDesire。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v412 — Coerce has* 叶门禁对偶（对齐 is*）

- **做了什么**：Coerce 为 Sandbox/Village 叶门禁补 hasBranded/hasParaded/hasAtoned/hasEyed 等 has*（= is*）；Spec 钉结构别名与 Insert 世界求值。无新实践 / 无 want 改动。
- **测**：CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v413 — Repute lacksRegardedAs 对偶

- **做了什么**：Repute 增加 lacksRegardedAs（regardedAs 的 Not 对偶）；Spec 钉结构与 Insert/净世界求值。无新实践 / 无 want 改动。
- **测**：ReputeSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v414 — Sandbox 叛逃/和解 want 名导出（钉既有门禁）

- **做了什么**：导出 `fleeDesireName`/`returnDesireName`；`sandboxDesires` 与 Spec 种子改用常量。
- **测**：SandboxSpec sandboxDesires: flee/return names registered。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v415 — Sandbox 无叛逃/无和解 want 时不自选（钉既有门禁）

- **做了什么**：Spec 钉 abandon 门开但 carol 仅 millJustice 时不选 abandon；flee 后 return 门开但无 returnDesire 时不选和解。无新实践。
- **测**：SandboxSpec wants: without fleeDesire / without returnDesire。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v416 — Host compliers/compliees/defiers/defiees + CLI

- **做了什么**：闭合视图枚举 `complied.*.<who>.*` / `complied.*.*.<who>` 与 `defied.*.*.<who>` / `defied.*.<who>.*`；CLI `prax compliers`/`compliees`/`defiers`/`defiees`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v417 — Chronicle compliers/compliees/defiers/defiees of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"compliers of "` / `"compliees of "` / `"defiers of "` / `"defiees of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v418 — Sandbox 沉默债 want 名导出（钉既有门禁）

- **做了什么**：导出 `millSilenceDesireName`/`millBreakSilenceDesireName`/`churchSilenceDesireName`/`churchBreakSilenceDesireName`；`sandboxDesires` 改用常量。
- **测**：SandboxSpec sandboxDesires: silence want names registered。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v419 — Sandbox 无买沉默 want 时不自选（钉既有门禁）

- **做了什么**：Spec 钉 ira 已 learn 后门开但 bob 无 millSilenceDesire 时不买；gale 已 hear 后门开但 eve 无 churchSilenceDesire 时不买。无新实践。
- **测**：SandboxSpec wants: without millSilenceDesire / without churchSilenceDesire。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v420 — Deontic hasObligedWhenAt 对偶

- **做了什么**：Deontic 增加 hasObligedWhenAt（= isObligedWhenAt）；Spec 钉结构别名与 whenAt 世界求值。无新实践 / 无 want 改动。
- **测**：DeonticSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v421 — Emotion lacksInMood 对偶

- **做了什么**：Emotion 增加 lacksInMood（inMood 的 Not 对偶）；Spec 钉结构与 setMood 世界求值。无新实践 / 无 want 改动。
- **测**：EmotionSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v422 — Kin/Confession/Witness Spec 补钉

- **做了什么**：Kin Spec 补 hasMarriedTo 世界求值；Confession Spec 补 lacksMark 世界求值；Witness Spec 钉 asRole 重定向。无新实践 / 无 want 改动。
- **测**：KinSpec / ConfessionSpec / WitnessSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v423 — Host wrongersOf/wrongeesOf + CLI

- **做了什么**：闭合视图枚举 `wronged.*.<who>` / `wronged.<who>.*`；CLI `prax wrongers`/`wrongees`；help 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v424 — Chronicle wrongers/wrongees of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"wrongers of "` / `"wrongees of "`（对齐 Host）；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。

## v425 — Sandbox 正义 want 名导出（钉既有门禁）

- **做了什么**：导出 seeks/punishes/exile/joins 与 bob 异端正义 want 名；`millJustice`/`churchJustice`/`bobHeresyJustice`/`iraJustice` 改用常量。
- **测**：SandboxSpec sandboxDesires: justice want names registered。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v426 — Sandbox 无撕毁/无惧烙 want 时不自选（钉既有门禁）

- **做了什么**：Spec 钉买沉默后门开但无 breakSilence 时 ira/gale 不 tear；squeeze/inquisit 后门开但无 fearsBrand 时 bob 不 confess/recant。无新实践。
- **测**：SandboxSpec wants: without breakSilence / churchBreakSilence / fearsBrand / fearsBrandHeretic。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v427 — Sandbox 权重交叉：放逐>控告、控告窗、双压审查（钉既有门禁）

- **做了什么**：Spec 钉 exile(12) 压 denounce；harvest 窗 denounce 优先；dualPressure 上 punishes-bob-heretic(9) 压 punishes-heretic(8)。无新实践。
- **测**：SandboxSpec wants: exile beats denounce / denounce beats cry harvest / bobHeresy censure beats eve。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v428 — Kin lacksParentOf 对偶

- **做了什么**：Kin 增加 lacksParentOf（= lacksChildOf 对调；isParentOf 的 Not）；Spec 钉结构与 kinWorld 求值。无新实践 / 无 want 改动。
- **测**：KinSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v429 — Debt lacksOwed 对偶

- **做了什么**：Debt 增加 lacksOwed（= neverOwed）；Spec 钉别名与 settle 世界求值。无新实践 / 无 want 改动。
- **测**：DebtSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v430 — Beliefs/Conversation/Faction lacks* 对偶

- **做了什么**：Beliefs lacksHoldsBelief（= doubts）；Conversation lacksTopic（= offTopic）；Faction lacksRegardAs（= lacksRegard）；Spec 钉结构与世界求值。无新实践 / 无 want 改动。
- **测**：BeliefsSpec / ConversationSpec / FactionSpec（针对性；未跑全量）。

## v431 — Sandbox 无婚入/无获知 want 时不自选（钉既有门禁）

- **做了什么**：Spec 钉 fran 空 want 不 wed；dave 无 seeksTheft 不 learn；priest 无 seeksHeresy 不 hear blasphemy。阵容 fran 改用 `joinsMillDesireName` 常量。
- **测**：SandboxSpec wants: without joinsMill / seeksTheft / seeksHeresy；cast fran holds joins。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v432 — Sandbox 权重交叉：和解/买沉默/教会放逐（钉既有门禁）

- **做了什么**：Spec 钉 flee 后 return(11) 自选和解；buy(14) 压 millJustice；censure 后 exileEve(12) 压审查 want。无新实践。
- **测**：SandboxSpec wants: return beats flee / silence buy beats millJustice / church exile beats censure。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v433 — Sandbox want 字符串改常量 + 撕毁权重/获知负例（钉既有门禁）

- **做了什么**：阵容 bob 与 Spec 种子/断言改用沉默/正义/声援/放逐常量；Spec 钉 tear(10) 压 millJustice、church tear 压 churchJustice；无 seeksBobHeresy 不 hear of bob；默认阵容不挂 coerce/parade/fearsBrand。
- **测**：SandboxSpec wants: breakSilence weight / church breakSilence weight / without seeksBobHeresy；cast default unhooks。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v434 — Sandbox 权重交叉：胁迫/叛逃压正义 + affiliate 空转（钉既有门禁）

- **做了什么**：Spec 钉 squeeze/inquisit 权重压 millCry/bobHeresyJustice；flee(9) 窗外压 millCry；kyle affiliate 空 want 只 Wait。无新实践。
- **测**：SandboxSpec wants: squeeze/inquisit/flee weight；affiliate kyle never picks mill justice。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v435 — Host eyers/eyees/confronters/confrontees + CLI

- **做了什么**：闭合视图枚举 `eyed.*.<who>` / `eyed.<who>.*` 与 `confronted.*.<who>` / `confronted.<who>.*`；CLI 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v436 — Chronicle eyers/eyees/confronters/confrontees of + Host 对偶

- **做了什么**：`askChronicle` 增加对应臂；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v437 — Host revokersOf/revokeesOf + CLI

- **做了什么**：闭合视图枚举 `revoked.*.<who>` / `revoked.<who>.*`；CLI `prax revokers`/`revokees`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v438 — Chronicle revokers/revokees of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"revokers of "` / `"revokees of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v439 — CLI in-laws/short-tempered 别名打磨

- **做了什么**：dispatch 接受 `inlaws` 与 `shortTempered`/`shorttempered`；help 注明别名。无实践 / 无 want 改动。
- **测**：编译；未跑全量。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v440 — Conversation hasTalkingWith/lacksTalkingWith 对偶

- **做了什么**：Conversation 增加 hasTalkingWith（= talkingWith）与 lacksTalkingWith（Not）；Spec 钉结构与 beginConversation 世界求值。无新实践 / 无 want 改动。
- **测**：ConversationSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v441 — Deontic hasInBreach/lacksInBreach/hasFulfilled 对偶

- **做了什么**：Deontic 增加 hasInBreach（= inBreach）、lacksInBreach（= lacksViolation）、hasFulfilled（= fulfilled）；Spec 钉结构与 breach/内容世界求值。无新实践 / 无 want 改动。
- **测**：DeonticSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v442 — Reactions hasReactionActive/lacksReactionActive + Coerce has* Spec 补钉

- **做了什么**：Reactions 增加 hasReactionActive / lacksReactionActive；Coerce Spec 补剩余 has* 叶门禁世界求值。无新实践 / 无 want 改动。
- **测**：ReactionsSpec / CoerceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v443 — Deceit hasLiedTo 对偶

- **做了什么**：Deceit 增加 hasLiedTo（= liedTo）；Spec 钉结构与 whisper 世界求值。无新实践 / 无 want 改动。
- **测**：DeceitSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v444 — Sight hasLastKnownAt/lacksLastKnownAt 对偶

- **做了什么**：Sight 增加 hasLastKnownAt（= lastKnownAt）与 lacksLastKnownAt（精确叶 Not）；Spec 钉结构与 Insert 世界求值。无新实践 / 无 want 改动。
- **测**：SightSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v445 — Sandbox 撕毁后控告权重 + parade/squeeze 门互斥（钉既有门禁）

- **做了什么**：Spec 钉 tear 后 harvest 窗 millJustice 选 denounce、church 选 censure；brand 后 squeeze 门关、parade(10) 自选游街（mill/church）。无新实践。
- **测**：SandboxSpec wants: after breakSilence denounce / after church tear censure / parade vs squeeze after brand。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未开 feat/my-town。

## v446 — Sandbox affiliate×want 负例扩展（钉既有门禁）

- **做了什么**：Spec 钉 kyle 挂 millCry/squeeze+parade/churchJustice+inquisit/flee 时门禁仍关、不选对应 act；挂 joinsMill 可 wed。无新实践。
- **测**：SandboxSpec wants: affiliate kyle with …。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v447 — Host ostracizers..paradees + CLI

- **做了什么**：闭合视图枚举 ostracized/denounced/censured/paraded 的 `*.<who>` / `<who>.*`；CLI 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v448 — Chronicle ostracizers..paradees of + Host 对偶

- **做了什么**：`askChronicle` 增加对应臂；Spec 钉原叶与短语对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v449 — Host criersOf/crieesOf/ralliersOf/rallieesOf + CLI

- **做了什么**：闭合视图枚举 `cried`/`rallied` 双边；CLI 同步。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v450 — Chronicle criers/criees/ralliers/ralliees of + Host 对偶

- **做了什么**：`askChronicle` 增加对应臂；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v451 — Host alliesOf + CLI

- **做了什么**：闭合视图枚举 `allied.<who>.*`（对齐 spousesOf）；CLI `prax allies`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v452 — Chronicle allies of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"allies of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v453 — Sandbox 欲望权重词汇钉 + 教会买沉默权重（钉既有门禁）

- **做了什么**：Spec 钉 sandboxDesires 全表 wantUtility；教会买沉默(14) 压过 churchJustice；市集 cry(7) 压过 millJustice；fearsBrand/Heretic 负权重选 confess/recant；parade once 后不可再游街。无新实践。
- **测**：SandboxSpec wants: desire weight vocabulary / church silence buy / cry weight / fearsBrand* / after parade once-gate。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未开 feat/my-town。

## v454 — Sandbox affiliate×want 负例再扩 + cast 默认挂载（钉既有门禁）

- **做了什么**：Spec 钉 kyle 挂 rally/cry/silence/bobHeresy 时门禁仍关；cast 默认 millCry/churchJustice/silence/kyle 空。无新实践。
- **测**：SandboxSpec wants: affiliate kyle with rally+cry / silence / bobHeresy；cast: default desire hooks。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v455 — Host resentersOf + CLI

- **做了什么**：闭合视图枚举 `resents.*.<who>`；CLI `prax resenters`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v456 — Chronicle resenters of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"resenters of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v457 — Host shunnersOf + CLI

- **做了什么**：闭合视图枚举 `shunned.*.<who>`；CLI `prax shunners`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v458 — Chronicle shunners of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"shunners of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v459 — Schedule lasts Spec 钉

- **做了什么**：ScheduleSpec 钉 lasts（Insert→InsertFor；非 Insert 响亮报错）。无新实践 / 无 want 改动。
- **测**：ScheduleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v460 — Arc arcOf Spec 钉

- **做了什么**：ArcSpec 钉 arcOf 路径辅助（who.arc）。无新实践 / 无 want 改动。
- **测**：ArcSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v461 — Minds believedDesires/cooked* Spec 钉

- **做了什么**：MindsSpec 钉 believedDesires（believedWants 背后 Desire 列表）与 cookedDesiresFor/cookedSelfWants（Owner 落地与自 want 合并）。无新实践 / 无 want 改动。
- **测**：MindsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v462 — Planner evaluateCooked Spec 钉

- **做了什么**：PlannerSpec 钉 evaluateCooked 与 evaluate/cookedSelfWants 同效用。无新实践 / 无 want 改动。
- **测**：PlannerSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v463 — Script 保留族头 + scriptPlayer Spec 钉 + pulse 名校验

- **做了什么**：ScriptSpec 钉 scenePatienceFamily/currentScenePath 常量与 scriptPlayer；ScheduleRuleSpec 补 pulse 多段名拒绝。无新实践 / 无 want 改动。
- **测**：ScriptSpec / ScheduleRuleSpec（针对性；未跑全量）。

## v464 — Host esteemersOf + CLI

- **做了什么**：闭合视图枚举 `esteemed.*.<who>.*`；CLI `prax esteemers`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v465 — Chronicle esteemers of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"esteemers of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v466 — Host scornersOf + CLI

- **做了什么**：闭合视图枚举 `scorned.*.<who>.*`；CLI `prax scorners`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v467 — Chronicle scorners of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"scorners of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v468 — Sandbox without-accuse / seek 正例 / 节庆 once-gate（钉既有门禁）

- **做了什么**：Spec 钉无 punishesThief/exileBob/punishesHeretic/exileEve 时不选控告/放逐；seeksTheft/Heresy 自选 learn/hear；denounce 后 exile 权重；parade 压 millCry；cry/rally once 后不可再做；coerce 欲望名 punishes-squeeze/inquisit。无新实践。
- **测**：SandboxSpec wants: without punishes* / exile* / seeks* / after denounce exile / parade weight / after cry|rally once-gate / coerce desire names。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未开 feat/my-town。

## v469 — Sandbox affiliate×fearsBrand 负例 + 玩家空槽（钉既有门禁）

- **做了什么**：Spec 钉 kyle 挂 fearsBrand 不可 confess；玩家槽无 desire/want。无新实践。
- **测**：SandboxSpec wants: affiliate kyle with fearsBrand；cast: player slot holds no desires。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v470 — Host bondersOf + CLI

- **做了什么**：闭合视图枚举 `bond.*.<who>.*`；CLI `prax bonders`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v471 — Chronicle bonders of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"bonders of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v472 — Host liarsOf + CLI

- **做了什么**：闭合视图枚举 `*.lied.<who>.*`；CLI `prax liars`。无实践 / 无 want 改动。
- **测**：HostSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v473 — Chronicle liars of + Host 对偶

- **做了什么**：`askChronicle` 增加 `"liars of "`；Spec 钉对偶。无实践 / 无 want 改动。
- **测**：ChronicleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v474 — Sandbox Desire Match 叶词汇 + seeksBob / churchParade 权重（钉既有门禁）

- **做了什么**：Spec 钉 Want Match 叶原子；seeksBobHeresy 自选 hear of bob；无 punishesBobHeretic 不 censure；churchParade 压 bobHeresyJustice；churchParade once；joinsMill 选 wed。无新实践。
- **测**：SandboxSpec wants: desire Match leaf / seeksBobHeresy / without punishesBobHeretic / churchParade weight / after churchParade once / joinsMill。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；未开 feat/my-town。

## v475 — Sandbox 买沉默 once + affiliate×exile + activate 幂等（钉既有门禁）

- **做了什么**：Spec 钉买沉默后无 want 不重买（mill/church）；kyle 挂 exile 不可放逐；activateSqueeze 幂等。无新实践。
- **测**：SandboxSpec wants: after silence/church buy … does not re-buy；affiliate kyle with exile；activateSqueeze idempotent。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准。

## v476 — Repute standingWith 导出 + Spec 钉

- **做了什么**：导出 standingWith（standing/standingUnless 共用核）；Spec 钉无额外守卫别名与额外守卫入 axiomWhen。无新实践 / 无 want 改动。
- **测**：ReputeSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v477 — Persist saveState/loadState Spec 钉

- **做了什么**：PersistSpec 钉 saveState/loadState 临时文件往返（相对 serialize/deserialize）。无新实践 / 无 want 改动。
- **测**：PersistSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v478 — Script beat/quip/goto/ending 结构 Spec 钉

- **做了什么**：ScriptSpec 钉 beat/quip/goto/ending 构造子字段形状。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v479 — Schedule sightRule 结构 Spec 钉

- **做了什么**：ScheduleRuleSpec 钉 sightRule 周期-1 体（Neq Seer/Seen、turn!Now、信念戳）。无新实践 / 无 want 改动。
- **测**：ScheduleRuleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v480 — Sandbox 正义包列表 + fearsBrand 叶 + tear 后门再开（钉既有门禁）

- **做了什么**：Spec 钉 millJustice/churchJustice/bobHeresyJustice/millCry 列表；fearsBrand 条件含 branded；无 cry 有 rally 时市集选 rally；tear 后 harvest 再开 denounce/censure；bob 异端 censure 后 banish。无新实践。
- **测**：SandboxSpec wants: justice bundle / fearsBrand conditions / without cry with rally / after mill|church tear gate / after bob heresy censure banish。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v481 — Sandbox activate 幂等 + affiliate tear 负例 + return/brand 正例（钉既有门禁）

- **做了什么**：Spec 钉 activateParade/inquisit/churchBob/churchParade 幂等；kyle 挂 breakSilence 不可 tear；仅 returnDesire 选归队；brand 后 bob 不再 confess。无新实践。
- **测**：SandboxSpec wants: activate* idempotent / affiliate millBreakSilence / after flee returnDesire / after brand no re-confess。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v482 — Sandbox 欲望名字符串词汇 + flee/tear once + defy→brand（钉既有门禁）

- **做了什么**：Spec 钉全表 desire 名字符串；仅 fleeDesire 选 abandon；tear 后 breakSilence 满足不重撕；defy 后 brand 自选（mill/church）；kyle 挂 inquisit 不可 squeeze。无新实践。
- **测**：SandboxSpec wants: desire name string / fleeDesire alone / after mill|church tear no re-tear / brand after defy / affiliate inquisit。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v483 — Sandbox cast Host 查询钉（钉既有门禁）

- **做了什么**：Spec 钉 kyle∈guild∉mill、priest∈church leaders、fran∉mill。无新实践。
- **测**：SandboxSpec cast: guild kyle and church leaders。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v484 — Script.Json saveScript/loadScript Spec 钉

- **做了什么**：JsonSpec 钉 saveScript/loadScript 临时文件往返（相对 encode/decode）。无新实践 / 无 want 改动。
- **测**：Script.JsonSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v485 — Script scenePatiencePath 导出 + Spec 钉

- **做了什么**：导出 scenePatiencePath（族头拼接）；Spec 钉 `scenePatience.<sid>.<j>`。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v486 — Sandbox 沉默债门禁 + activate 不挂 want + 节庆错峰（钉既有门禁）

- **做了什么**：Spec 钉买沉默后 denounce/censure 关闭、tear 后再开；activateSqueeze/Parade 不往阵容挂 want；parade 后 exile 仍开；harvest/market 错峰。无新实践。
- **测**：SandboxSpec wants: after mill|church buy … closed until tear / activate* does not hang / exile after parade / harvest and market stagger；cast: playerName。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v487 — Sandbox 叛逃溶解 regard + return 复门 + desire 注册表（钉既有门禁）

- **做了什么**：Spec 钉受害方 flee 溶解 mill regard（dave 无 denounce）；return 后 carol 可控告；bobHeresy(9)>denounce(8) 数值；仅 paradeDesire 选游街；kyle 挂 churchBreak 不可 tear；sandboxDesires 注册全导出名。无新实践。
- **测**：SandboxSpec wants: after victim flee / after return denounce / bobHeresy weight 9 / paradeDesire alone / affiliate churchBreakSilence / sandboxDesires registers。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实；未改 Village 金标准；不碰 feat/my-town。

## v488 — Planner candidateActions Spec 钉

- **做了什么**：PlannerSpec 钉 candidateActions（死者空；未绑定=possibleActions；boundTo 过滤）。无新实践 / 无 want 改动。
- **测**：PlannerSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v489 — Script wanting 结构 Spec 钉

- **做了什么**：ScriptSpec 钉 wanting 追加 castDesires 字段形状。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v490 — Minds professed/conventional 公理 Spec 钉

- **做了什么**：MindsSpec 钉 professed/conventional 的 axiomWhen/axiomThen 形状。无新实践 / 无 want 改动。
- **测**：MindsSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v491 — Repute scorn/esteem 构造响亮段错误 Spec 钉

- **做了什么**：ReputeSpec 钉 scornStanding/esteemStanding/scornDesire/esteemDesire 点号段响亮报错。无新实践 / 无 want 改动。
- **测**：ReputeSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v492 — Persona transparent/bearFromRegard 公理 Spec 钉

- **做了什么**：PersonaSpec 钉 transparent/bearFromRegard 的 axiomWhen/axiomThen 形状。无新实践 / 无 want 改动。
- **测**：PersonaSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v493 — Script member/player/after/timeout + scriptPlayer 空阵容 Spec 钉

- **做了什么**：ScriptSpec 钉 member/player 与 after/timeout 字段形状；无 playable 时 scriptPlayer 响亮报错。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v494 — Persist formatVersion Spec 钉

- **做了什么**：PersistSpec 钉 formatVersion = prax-state v4。无新实践 / 无 want 改动。
- **测**：PersistSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v495 — Arc adoptArc Action 形状 + 点号段错误 Spec 钉

- **做了什么**：ArcSpec 钉 adoptArc 的 Not/Insert Action 形状与点号 stage 响亮报错。无新实践 / 无 want 改动。
- **测**：ArcSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v496 — Rumor gossipPublic 无主体模式错误 Spec 钉

- **做了什么**：RumorSpec 钉 gossipPublic 无变量事迹模式响亮报错（对偶 gossip）。无新实践 / 无 want 改动。
- **测**：RumorSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v497 — Schedule 节庆门禁名段错误 Spec 钉

- **做了什么**：ScheduleSpec 钉 duringFestival/outsideFestival/hasFestival/lacksFestival 点号/空名响亮报错。无新实践 / 无 want 改动。
- **测**：ScheduleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v498 — Project endeavorCrew 构造响亮错误 Spec 钉

- **做了什么**：ProjectSpec 钉 endeavorCrew 无部件/点号 id 响亮报错（对偶 endeavor）。无新实践 / 无 want 改动。
- **测**：ProjectSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v499 — Script withTraits/concernedWith 单独追加 Spec 钉

- **做了什么**：ScriptSpec 钉 withTraits/concernedWith 各自单独追加 castTraits/castDesires。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v500 — Sandbox 交叉 once-gate + affiliate×want 边角 Spec

- **做了什么**：SandboxSpec 追加 rally×exile、return×squeeze/parade/cry、parade once×cry/rally、churchParade×mill cry、dual tear/brand/parade；affiliate kyle 挂 paradeDesire/churchParadeDesire/fearsBrandHeretic/seeksTheft/punishesThief 门禁关闭；fran 未婚 millCry；cry once 后 rally 仍拣；denounce 后 market cry 开但 exile 胜拣。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（264 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v501 — Chronicle short-tempered of 别名 + Host/CLI 对偶 Spec

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`short-tempered of` 与既有 `shortTempered of` / Host `shortTemperedOf` / CLI `short-tempered` 同义；Spec 钉别名与空集文案。

## v502 — Chronicle moods/arcs/ages of 原始叶对偶 + Spec

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`moods of`/`arcs of`/`ages of` 返回与 Host `moodsOf`/`arcsOf`/`agesOf` 对齐的原始叶；既有短语化 `mood`/`arc`/`age of` 不变；Spec 钉正例与空集。

## v503 — Chronicle leaders of 别名 + Host leadersOf 对偶 Spec

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`leaders of` 与 `leads of` / Host `leadersOf` / CLI `leaders` 同义；Spec 钉别名与空派系文案。

## v504 — Persist 畸形存档行响亮错误 Spec 钉

- **做了什么**：PersistSpec 钉 deserializeState 对畸形 intention/due/expiry/rngseed 行响亮报错。无新实践 / 无 want 改动。
- **测**：PersistSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v505 — Project endeavorCrew 其余构造守卫 Spec 钉

- **做了什么**：ProjectSpec 钉 endeavorCrew 对偶 endeavor 的部件名段/重名/悬边/自环/Prax 保留名响亮报错。无新实践 / 无 want 改动。
- **测**：ProjectSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v506 — Persona cast 重复特质名 Spec 钉

- **做了什么**：PersonaSpec 钉 cast 对重复特质名响亮报错。无新实践 / 无 want 改动。
- **测**：PersonaSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v507 — Sandbox return×门禁 + 共享流放竞速 + affiliate cry/rally Spec

- **做了什么**：SandboxSpec 追加 return×denounce/exile/rally；共享 exiled.bob 竞速（mill exile↔priest banish）；exile×parade 独立；fran squeezeDesire 婚前门禁；silence×flee（债叶存、买门关）；wed×tear；parade 权重胜 cry；brand 后不可再 brand；kyle rallyDesire/cryDesire 门禁关；cry/rally once×squeeze。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（279 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v508 — Host chattersOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`chattersOf` 枚举 `*.chattedWith.<who>`；CLI `prax chatters <who> <world>`。

## v509 — Chronicle chatters of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`chatters of` 短语化聊天人；Spec 钉 Host 叶与 Chronicle 短语及空集。

## v510 — Script.Json CmpOp 往返与未知算子 Spec 钉

- **做了什么**：Script.JsonSpec 钉每个 CmpOp JSON 往返，以及未知 cmp/calc 标签解码失败。无新实践 / 无 want 改动。
- **测**：Script.JsonSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v511 — Rumor gossipPublic Prax 命名空间 Spec 钉

- **做了什么**：RumorSpec 钉 gossipPublic 对偶 gossip 的门禁/事件模式 Prax 保留名响亮报错。无新实践 / 无 want 改动。
- **测**：RumorSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v512 — Persona Trait 字段访问 Spec 钉

- **做了什么**：PersonaSpec 钉 Trait 的 traitName/traitDesires 字段。无新实践 / 无 want 改动。
- **测**：PersonaSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v513 — Sandbox parade/tear 交叉 + affiliate heresy/wed Spec

- **做了什么**：SandboxSpec 追加 parade once×denounce、churchParade×mill denounce、tear×异轨沉默独立、wed×cry、kyle seeksHeresy/punishesHeretic/joinsMill（可 wed 获站队）、parade 后 cryDesire 独拣、millBreak 权重胜 cry、brand 路径×cry、censure once×cry、denounce×church squeeze、kyle millSilence 不买。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（294 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v514 — Chronicle regards by + Host regardsOf 对偶 Spec

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`regards by` 返回观察者发出的 `regards.<who>.*` 原始叶，对齐 Host `regardsOf`；与既有目标侧 `regards of` / `regards toward` 并存；Spec 钉正例与空集。

## v515 — Script.Json 其余 Condition 构造往返 Spec 钉

- **做了什么**：Script.JsonSpec 钉 Eq/Count/Subquery/Or/Absent/Exists 的 JSON 往返。无新实践 / 无 want 改动。
- **测**：Script.JsonSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v516 — Schedule pulse 空名响亮错误 Spec 钉

- **做了什么**：ScheduleRuleSpec 钉 pulse 空名响亮报错（对偶点号名）。无新实践 / 无 want 改动。
- **测**：ScheduleRuleSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v517 — Project endeavorCrew 双环不可达 Spec 钉

- **做了什么**：ProjectSpec 钉 endeavorCrew 双环部件不可达响亮报错（对偶 endeavor）。无新实践 / 无 want 改动。
- **测**：ProjectSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v518 — Sandbox exile×parade 双轨 + dual coerce 序 + affiliate heresy Spec

- **做了什么**：SandboxSpec 追加 mill exile×church parade、priest banish×mill parade；cry/rally once×denounce；fran rally 婚前关闭；kyle exileEve/seeksBobHeresy/punishesBobHeretic 门禁；无 paradeDesire 不拣；squeeze=parade 权重钉；repay 关 tear；dual coerce 正反序；returnDesire 胜 flee。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（309 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v519 — Script.Json Insert/Delete/Call 往返 Spec 钉

- **做了什么**：Script.JsonSpec 钉 Insert/Delete/Call Outcome 的 JSON 往返。无新实践 / 无 want 改动。
- **测**：Script.JsonSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v520 — Script scene 默认空字段 Spec 钉

- **做了什么**：ScriptSpec 钉 scene 构造器默认 opening/setup/beats/junctions 为空。无新实践 / 无 want 改动。
- **测**：ScriptSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v521 — Host occupantsOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`occupantsOf` 枚举 `at.*.<place>`；CLI `prax occupants <place> <world>`。

## v522 — Chronicle occupants of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`occupants of` 短语化在场角色；Spec 钉 Host 叶与 Chronicle 短语及空集。

## v523 — Sandbox tear复门 + debt×cry + fran coerce 链 + affiliate silence Spec

- **做了什么**：SandboxSpec 追加 tear 后 denounce/censure 复开；silence debt 下 cry 仍开；church debt 堵 gale 不堵 priest；fran wed×squeeze×parade 链；kyle churchSilence；brand 后 fears 满足；denounce×rally；censure×squeeze；exile 权重胜 rally；flee×church hear；无 joinsMill 不拣 wed。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（324 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v524 — Host holdersOf/carriersOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`holdersOf`/`carriersOf` 枚举 `holding.*.<item>` / `carrying.*.<item>`；CLI `holders`/`carriers`。

## v525 — Chronicle holders/carriers of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`holders of`/`carriers of` 短语化持有/携带人；Spec 钉 Host 叶与 Chronicle 短语及空集。

## v526 — Cooked cookPractice/Functions/ScheduleRule Spec 钉

- **做了什么**：CookedSpec 钉 cookPractice 实例路径与动作/init 煮熟，以及 cookFunctions/cookScheduleRule 键控与体。无新实践 / 无 want 改动。
- **测**：CookedSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v527 — Query satisfies/count/conditionVars/condSents Spec 钉

- **做了什么**：QuerySpec 钉 satisfies/countSatisfying 与 conditionVars/condSents 行走。无新实践 / 无 want 改动。
- **测**：QuerySpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v528 — Derive axiomHeadPatterns Spec 钉

- **做了什么**：DeriveSpec 钉 axiomHeadPatterns 收集煮熟头路径。无新实践 / 无 want 改动。
- **测**：DeriveSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。
## v529 — Sandbox dual parade 闭合 + cry/rally×exile + affiliate justice Spec

- **做了什么**：SandboxSpec 追加 parade/churchParade once 后 squeeze 闭；kyle 默认 Wait；silence 权重钉；dual parade 双闭；cry/rally once 后 exile 路径仍开；kyle 挂 bobHeresy/churchJustice 仍无门；defy-brand×cry；权重链；return×church debt。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（337 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。
## v530 — Types Spec 钉（turnPath/dead/living/isPraxVar/outcomeVars）

- **做了什么**：新增 TypesSpec，钉 turnPath、deadSentence、livingCharacters、isPraxVar、authoredPatClash、outcomeVars/outcomeSents、emptyState 时钟种子。无新实践 / 无 want 改动。
- **测**：TypesSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v531 — Inspect Spec 钉（firstFailing/explain/explainMatching）

- **做了什么**：新增 InspectSpec，钉 firstFailing 左失败合取与 explain/explainMatching 可用/阻塞行。无新实践 / 无 want 改动。
- **测**：InspectSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v532 — Db childKeys/isVariable/dbExcl/dbAsserted Spec 钉

- **做了什么**：DbSpec 钉 childKeys、isVariable、dbExcl/dbAsserted 与排他/断言端点。无新实践 / 无 want 改动。
- **测**：DbSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v533 — Engine currentTurn 守卫 Spec 钉

- **做了什么**：EngineSpec 钉 currentTurn 读种子时钟，以及缺槽/多子时响亮报错。无新实践 / 无 want 改动。
- **测**：EngineSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v534 — Host affiliatorsOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`affiliatorsOf` 枚举 `affiliate.*.<faction>` 的 who；CLI `prax affiliators <faction> <world>`。

## v535 — Chronicle affiliators of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`affiliators of` 短语化次级归属人；Spec 钉 Host 名与 Chronicle 短语及空集。
## v536 — Relevance eviction/atoms/bearing/producible Spec 钉

- **做了什么**：RelevanceSpec 钉 evictionShadowNames、cookedOutcomeAtoms/cookedFnPool、bearingTemplates、producibleAtoms。无新实践 / 无 want 改动。
- **测**：RelevanceSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v537 — Stress runRandom ending/family Spec 钉

- **做了什么**：StressSpec 钉 runRandom 在预置 ending/family 世界上的 endingReached 与 visit。无新实践 / 无 want 改动。
- **测**：StressSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v538 — Sandbox tear×cry + denounce×squeeze + affiliate mill/ira Spec

- **做了什么**：SandboxSpec 追加 tear×cry、church tear×mill cry、denounce×squeeze、censure×parade、exile×cry 独立、banish×squeeze、wed×silence buy、kyle millJustice/iraJustice 门禁、parade/churchParade 独拣、flee×ira tear、return×ira debt、squeezeDesire/inquisitDesire 独拣。导入 iraJustice。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（352 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。
## v539 — Db valToSym/insertToks/retractNames Spec 钉

- **做了什么**：DbSpec 钉 valToSym、insertToks 与 retractNames 相对 insert/retract 的等价。无新实践 / 无 want 改动。
- **测**：DbSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v540 — Derive runCooked Spec 钉

- **做了什么**：DeriveSpec 钉 runCooked 对已闭模型上的 delta 与 closureFrom 一致。无新实践 / 无 want 改动。
- **测**：DeriveSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v541 — Derive runCooked Spec 入口形修正

- **做了什么**：runCooked 钉改为与 closureFrom 同入口（model ∪ facts, delta = facts）。无新实践 / 无 want 改动。
- **测**：DeriveSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。

## v542 — Sandbox exile 权重拣 + silence 窗/revoke + parade×inquisit Spec

- **做了什么**：SandboxSpec 追加 cry/rally once 后 exile 权重拣；dual brand 双 parade+cry；silence 买禁 harvest；revoke 禁再买；kyle squeezeDesire；无 fearsBrand/Heretic 不拣 confess/recant；mill parade×church squeeze / 反向；joinsMill=10 权重钉；kyle 空欲望；repay 后 ira denounce。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（367 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。
## v543 — Engine renderText Spec 钉

- **做了什么**：EngineSpec 钉 renderText 绑定替换与未知/未闭合括号行为。无新实践 / 无 want 改动。
- **测**：EngineSpec（针对性；未跑全量）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准。
## v544 — Host practitionersOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`practitionersOf` 枚举 `practice.<pid>.*`；CLI `prax practitioners <pid> <world>`。

## v545 — Chronicle practitioners of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`practitioners of` 返回实践 id 侧叶；Spec 钉 Host 与 Chronicle 空集。

## v546 — Chronicle festivals/stall 别名 + Spec

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`festivals`/`stall` 与既有 `what festivals`/`what is on the stall` 同义，对齐 Host `festivalsOf`/`stallOf`；Spec 钉别名。

## v547 — Host believersOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`believersOf` 枚举 `*.believes.<prop>…`；CLI `prax believers <prop> <world>`。

## v548 — Chronicle believers of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`believers of` 返回信念内容侧叶；Spec 钉 Host 与 Chronicle 空集。
## v549 — Sandbox revoke×buy 交叉 + church repay censure + parade/cry 窗 Spec

- **做了什么**：SandboxSpec 追加 church repay→gale censure；revoke mill/church×对侧 buy 独立与 dual revoke；mill exile×church squeeze；cry once×churchParade；parade once×cry；brand 后 parade 非窗立刻开而 cry 等 market；kyle exileBobDesire；flee 无买→return 再开 buy；tear×对侧 buy；churchParade=parade util；banish×mill cry。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（381 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v550 — Host notorietiesOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`notorietiesOf` 枚举 `notorious.*.<label>`；CLI `prax notorieties <label> <world>`。

## v551 — Chronicle notorieties of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`notorieties of` 返回恶名标签侧叶；Spec 钉 Host 与 Chronicle 空集。
## v552 — Sandbox cry/rally×inquisit + flee×parade + dual repay Spec

- **做了什么**：SandboxSpec 追加 cry/rally once×inquisit；parade once×rally；dual brand×cry/parade 独立；kyle returnDesire；flee×parade 关/return 复；dual repay 双轨 harvest 开；denounce/censure once×次市 cry；mill exile×ira tear；kyle churchParade；repay 后 ira cry。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（393 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v553 — Host traitedOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`traitedOf` 枚举 `trait.*.<trait>`；CLI `prax traited <trait> <world>`。

## v554 — Chronicle traited of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`traited of` 返回性格标签侧叶；Spec 钉 Host 与 Chronicle 空集。
## v555 — Sandbox parade×exile 权重 + flee×squeeze/parade + dual tear Spec

- **做了什么**：SandboxSpec 追加 churchParade once×rally；brand×denounce；confess×flee/return；brand×buy 仍开；parade×exile 权重拣；return×cry；flee×squeeze；gale 无 mill cry；kyle bobHeresy 不 banish；dual tear 双轨恢复；squeeze 中途×cry；无 churchParadeDesire 不拣 parade。无新实践 / 无 want 改动。
- **测**：`stack test --fast --test-arguments '--pattern /Sandbox/'`（405 绿）。
- **明确未做**：无 PWIM / 嵌套信念 / 硬 Swaygent / 反事实放置；未动 Village 金标准；未碰 feat/my-town。

## v556 — Host moodedOf + CLI

- **模块**：`src/Prax/Host.hs`、`app/Main.hs`
- **内容**：`moodedOf` 枚举 `mood.*.<mood>`；CLI `prax mooded <mood> <world>`。

## v557 — Chronicle mooded of + Host 对偶

- **模块**：`src/Prax/Chronicle.hs`、`test/Prax/HostSpec.hs`、`test/Prax/ChronicleSpec.hs`
- **内容**：`mooded of` 返回心境标签侧叶；Spec 钉 Host 与 Chronicle 空集。
