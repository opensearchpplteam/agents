# PPL Command Catalog

Complete list of PPL commands from `OpenSearchPPLParser.g4` with syntax.

## Data Source Commands

| Command | Syntax | Since |
|---------|--------|-------|
| search | `[search] source=<index> [search-expr]*` | 1.0 |
| describe | `describe <table>` | 2.1 |
| show datasources | `show datasources` | 2.4 |
| multisearch | `multisearch [subsearch]+` | 3.4 |

## Filtering Commands

| Command | Syntax | Since |
|---------|--------|-------|
| where | `where <logical-expr>` | 1.0 |
| head | `head [N] [from M]` | 1.0 |
| dedup | `dedup [N] <field-list> [keepempty=bool] [consecutive=bool]` | 1.0 |
| regex | `regex <field> = \|!= <pattern>` | 3.3 |

## Field Manipulation Commands

| Command | Syntax | Since |
|---------|--------|-------|
| fields | `fields [+\|-] <field-list>` | 1.0 |
| table | `table <field-list>` | 3.3 |
| rename | `rename <field> AS <new-field> [, ...]` | 1.0 |
| eval | `eval <field>=<expr> [, <field>=<expr>]` | 1.0 |
| fillnull | `fillnull [with <val> [in <fields>]] \| [using <field>=<val>, ...]` | 3.0 |
| replace | `replace <pattern> WITH <replacement> [, ...] IN <field-list>` | 3.4 |
| expand | `expand <field> [as <alias>]` | 3.1 |
| flatten | `flatten <field> [as (<alias-list>)]` | 3.1 |
| mvcombine | `mvcombine <field> [delim=<str>]` | 3.5 |

## Aggregation Commands

| Command | Syntax | Since |
|---------|--------|-------|
| stats | `stats [args] <agg-func> [, ...] [by <field-list>\|span(...)]` | 1.0 |
| eventstats | `eventstats [args] <agg-func> [, ...] [by <field-list>]` | 3.1 |
| streamstats | `streamstats [args] <agg-func> [, ...] [by <field-list>]` | 3.4 |

## Sorting & Ranking Commands

| Command | Syntax | Since |
|---------|--------|-------|
| sort | `sort [count] [+\|-]<field> [, ...]` | 1.0 |
| reverse | `reverse` | 3.2 |
| top | `top [N] [options] <field-list> [by <field-list>]` | 1.0 |
| rare | `rare [N] [options] <field-list> [by <field-list>]` | 1.0 |
| bin | `bin <field> [span=<val>] [bins=N] [as <alias>]` | 3.3 |

## Parsing Commands

| Command | Syntax | Since |
|---------|--------|-------|
| parse | `parse <field> <regex-pattern>` | 1.0 |
| grok | `grok <field> <grok-pattern>` | 2.4 |
| rex | `rex field=<field> [options] <pattern>` | 3.3 |
| spath | `spath [input=<field>] [output=<field>] [path=<path>]` | 3.3 |
| patterns | `patterns <field> [by <fields>] [options]` | 2.4 |

## Data Combination Commands

| Command | Syntax | Since |
|---------|--------|-------|
| join | `[type] join [options] <right-source> [on <condition>]` | 3.0 |
| lookup | `lookup <table> <mapping-list> [append\|replace\|output <fields>]` | 3.0 |
| append | `append [subsearch]` | 3.3 |
| appendcol | `appendcol [override=bool] [sub-pipeline]` | 3.1 |
| appendpipe | `appendpipe [sub-pipeline]` | 3.5 |

## Charting & Visualization Commands

| Command | Syntax | Since |
|---------|--------|-------|
| timechart | `timechart [options] <agg-func> [by <field>]` | 3.3 |
| chart | `chart [options] <agg-func> [over <row>] [by <col>]` | 3.4 |
| trendline | `trendline [sort <field>] <type>(<N>, <field>) [as <alias>] [...]` | 3.0 |
| addtotals | `addtotals [fields] [options]` | 3.5 |
| addcoltotals | `addcoltotals [fields] [options]` | 3.5 |
| transpose | `transpose [N] [column_name=<str>]` | 3.5 |

## Machine Learning Commands

| Command | Syntax | Since |
|---------|--------|-------|
| kmeans | `kmeans [centroids=N] [iterations=N] [distance_type=str]` | 1.3 |
| ad | `ad [parameters...]` (deprecated) | 1.3 |
| ml | `ml [parameters...]` | 2.5 |

## Utility Commands

| Command | Syntax | Since |
|---------|--------|-------|
| explain | `explain [mode] <query>` | 3.1 |

## Join Types

```
INNER, LEFT [OUTER], RIGHT [OUTER], FULL [OUTER], CROSS, LEFT SEMI, LEFT ANTI
```

## Sort Field Types

```
auto(<field>), str(<field>), ip(<field>), num(<field>)
Direction: +/- prefix or asc/desc/a/d suffix
```

## Stats Arguments

```
partitions=N, allnum=bool, delim=str, bucket_nullable=bool, dedup_splitvalues=bool
```

## Streamstats Arguments

```
current=bool, window=N, global=bool, reset_before=<expr>, reset_after=<expr>
```
