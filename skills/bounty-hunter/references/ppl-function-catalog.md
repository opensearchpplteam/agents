# PPL Function Catalog

Complete list of PPL functions extracted from `OpenSearchPPLParser.g4` and docs.

## Aggregation Functions (stats/eventstats/streamstats)

| Function | Signature | Description |
|----------|-----------|-------------|
| COUNT / C | `count()` or `count(<expr>)` | Count rows |
| SUM | `sum(<field>)` | Sum of values |
| AVG | `avg(<field>)` | Average |
| MIN | `min(<field>)` | Minimum |
| MAX | `max(<field>)` | Maximum |
| VAR_SAMP | `var_samp(<field>)` | Sample variance |
| VAR_POP | `var_pop(<field>)` | Population variance |
| STDDEV_SAMP | `stddev_samp(<field>)` | Sample standard deviation |
| STDDEV_POP | `stddev_pop(<field>)` | Population standard deviation |
| PERCENTILE | `percentile(<field>, <pct>)` | Percentile value |
| PERCENTILE_APPROX | `percentile_approx(<field>, <pct> [, <compression>])` | Approximate percentile |
| MEDIAN | `median(<field>)` | Median (50th percentile) |
| DISTINCT_COUNT / DC | `distinct_count(<field>)` | Count distinct values |
| DISTINCT_COUNT_APPROX | `distinct_count_approx(<field>)` | Approximate distinct count |
| TAKE | `take(<field> [, <size>])` | Take N values |
| VALUES | `values(<field>)` | Unique sorted values |
| LIST | `list(<field>)` | All values (preserves dupes) |
| FIRST | `first(<field>)` | First value |
| LAST | `last(<field>)` | Last value |
| EARLIEST | `earliest(<field>)` | Earliest by time |
| LATEST | `latest(<field>)` | Latest by time |
| PER_SECOND | `per_second(<field>)` | Rate per second |
| PER_MINUTE | `per_minute(<field>)` | Rate per minute |
| PER_HOUR | `per_hour(<field>)` | Rate per hour |
| PER_DAY | `per_day(<field>)` | Rate per day |

### Percentile Shortcuts
- `P<N>(<field>)` or `PERC<N>(<field>)` - e.g., `P95(latency)`, `PERC50(value)`

## Window Functions (eventstats/streamstats only)

| Function | Description |
|----------|-------------|
| ROW_NUMBER | Sequential row number |
| RANK | Rank with gaps for ties |
| DENSE_RANK | Rank without gaps |
| PERCENT_RANK | Percentile rank |
| CUME_DIST | Cumulative distribution |
| NTH | Nth value in window |
| NTILE | Distribute into N buckets |

## Mathematical Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| ABS | `abs(<val>)` | Absolute value |
| CEIL / CEILING | `ceil(<val>)` | Round up to integer |
| FLOOR | `floor(<val>)` | Round down to integer |
| ROUND | `round(<val> [, <places>])` | Round to N decimal places |
| TRUNCATE | `truncate(<val>, <places>)` | Truncate to N decimal places |
| SQRT | `sqrt(<val>)` | Square root |
| CBRT | `cbrt(<val>)` | Cube root |
| POW / POWER | `pow(<base>, <exp>)` | Exponentiation |
| EXP | `exp(<val>)` | e^x |
| EXPM1 | `expm1(<val>)` | e^x - 1 |
| LN | `ln(<val>)` | Natural logarithm |
| LOG | `log(<val>)` | Logarithm base 10 |
| LOG (2-arg) | `log(<base>, <val>)` | Logarithm with base |
| MOD / MODULUS | `mod(<a>, <b>)` | Modulo |
| SIGN | `sign(<val>)` | Sign (-1, 0, 1) |
| SIGNUM | `signum(<val>)` | Sign function |
| RINT | `rint(<val>)` | Round to nearest int |
| RAND | `rand()` or `rand(<seed>)` | Random number [0,1) |
| PI | `pi()` | Pi constant |
| E | `e()` | Euler's number |
| CONV | `conv(<val>, <from>, <to>)` | Base conversion |
| CRC32 | `crc32(<str>)` | CRC-32 checksum |

## Trigonometric Functions

| Function | Signature |
|----------|-----------|
| SIN | `sin(<val>)` |
| COS | `cos(<val>)` |
| TAN | `tan(<val>)` |
| COT | `cot(<val>)` |
| ASIN | `asin(<val>)` |
| ACOS | `acos(<val>)` |
| ATAN | `atan(<val>)` |
| ATAN2 | `atan2(<y>, <x>)` |
| SINH | `sinh(<val>)` |
| COSH | `cosh(<val>)` |
| DEGREES | `degrees(<radians>)` |
| RADIANS | `radians(<degrees>)` |

## String Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| CONCAT | `concat(<str>, <str>, ...)` | Concatenate strings |
| CONCAT_WS | `concat_ws(<sep>, <str>, ...)` | Concatenate with separator |
| LENGTH | `length(<str>)` | Length in bytes |
| LOWER | `lower(<str>)` | To lowercase |
| UPPER | `upper(<str>)` | To uppercase |
| TRIM | `trim(<str>)` | Trim whitespace |
| LTRIM | `ltrim(<str>)` | Left trim |
| RTRIM | `rtrim(<str>)` | Right trim |
| SUBSTR / SUBSTRING | `substr(<str>, <start> [, <len>])` | Extract substring |
| LEFT | `left(<str>, <len>)` | Left N chars |
| RIGHT | `right(<str>, <len>)` | Right N chars |
| LOCATE | `locate(<substr>, <str> [, <pos>])` | Find position |
| POSITION | `position(<substr> IN <str>)` | Find position |
| REPLACE | `replace(<str>, <from>, <to>)` | Replace all occurrences |
| REVERSE | `reverse(<str>)` | Reverse string |
| ASCII | `ascii(<str>)` | ASCII code of first char |
| STRCMP | `strcmp(<str1>, <str2>)` | Compare strings |
| REGEXP_REPLACE | `regexp_replace(<str>, <pattern>, <replacement>)` | Regex replace |
| TOSTRING | `tostring(<val>)` | Convert to string |
| TONUMBER | `tonumber(<str>)` | Convert to number |

## Date and Time Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| NOW | `now()` | Current timestamp (UTC) |
| SYSDATE | `sysdate()` | Current timestamp |
| CURDATE / CURRENT_DATE | `curdate()` | Current date |
| CURTIME / CURRENT_TIME | `curtime()` | Current time |
| CURRENT_TIMESTAMP | `current_timestamp()` | Current timestamp |
| LOCALTIME | `localtime()` | Current time |
| LOCALTIMESTAMP | `localtimestamp()` | Current timestamp |
| UTC_DATE | `utc_date()` | Current UTC date |
| UTC_TIME | `utc_time()` | Current UTC time |
| UTC_TIMESTAMP | `utc_timestamp()` | Current UTC timestamp |
| DATE | `date(<expr>)` | Extract date |
| TIME | `time(<expr>)` | Extract time |
| TIMESTAMP | `timestamp(<expr>)` | Create timestamp |
| DATETIME | `datetime(<date>, <time>)` | Create datetime |
| ADDDATE / DATE_ADD | `adddate(<date>, <interval>)` | Add interval |
| SUBDATE / DATE_SUB | `subdate(<date>, <interval>)` | Subtract interval |
| ADDTIME | `addtime(<time1>, <time2>)` | Add time |
| SUBTIME | `subtime(<time1>, <time2>)` | Subtract time |
| DATEDIFF | `datediff(<date1>, <date2>)` | Difference in days |
| TIMEDIFF | `timediff(<time1>, <time2>)` | Difference in time |
| TIMESTAMPADD | `timestampadd(<unit>, <amt>, <ts>)` | Add to timestamp |
| TIMESTAMPDIFF | `timestampdiff(<unit>, <ts1>, <ts2>)` | Diff timestamps |
| DATE_FORMAT | `date_format(<date>, <format>)` | Format date |
| TIME_FORMAT | `time_format(<time>, <format>)` | Format time |
| STR_TO_DATE | `str_to_date(<str>, <format>)` | Parse date string |
| STRFTIME | `strftime(<ts>, <format>)` | Format timestamp |
| GET_FORMAT | `get_format(<type>, <locale>)` | Get format string |
| EXTRACT | `extract(<part> FROM <datetime>)` | Extract date part |
| YEAR | `year(<date>)` | Extract year |
| MONTH | `month(<date>)` | Extract month |
| DAY / DAYOFMONTH | `day(<date>)` | Extract day |
| HOUR | `hour(<time>)` | Extract hour |
| MINUTE | `minute(<time>)` | Extract minute |
| SECOND | `second(<time>)` | Extract second |
| MICROSECOND | `microsecond(<time>)` | Extract microsecond |
| DAYOFWEEK / DAY_OF_WEEK | `dayofweek(<date>)` | Day of week (1=Sun) |
| DAYOFYEAR / DAY_OF_YEAR | `dayofyear(<date>)` | Day of year |
| DAYNAME | `dayname(<date>)` | Day name |
| MONTHNAME | `monthname(<date>)` | Month name |
| MONTH_OF_YEAR | `month_of_year(<date>)` | Month of year |
| WEEK / WEEK_OF_YEAR | `week(<date>)` | Week of year |
| WEEKDAY | `weekday(<date>)` | Weekday (0=Mon) |
| QUARTER | `quarter(<date>)` | Quarter |
| YEARWEEK | `yearweek(<date>)` | Year and week |
| HOUR_OF_DAY | `hour_of_day(<time>)` | Hour of day |
| MINUTE_OF_HOUR | `minute_of_hour(<time>)` | Minute of hour |
| MINUTE_OF_DAY | `minute_of_day(<time>)` | Minute of day |
| SECOND_OF_MINUTE | `second_of_minute(<time>)` | Second of minute |
| LAST_DAY | `last_day(<date>)` | Last day of month |
| MAKEDATE | `makedate(<year>, <dayOfYear>)` | Create date |
| MAKETIME | `maketime(<hour>, <min>, <sec>)` | Create time |
| FROM_DAYS | `from_days(<N>)` | Days to date |
| TO_DAYS | `to_days(<date>)` | Date to days |
| TO_SECONDS | `to_seconds(<date>)` | Date to seconds |
| FROM_UNIXTIME | `from_unixtime(<epoch>)` | Epoch to timestamp |
| UNIX_TIMESTAMP | `unix_timestamp(<ts>)` | Timestamp to epoch |
| SEC_TO_TIME | `sec_to_time(<sec>)` | Seconds to time |
| TIME_TO_SEC | `time_to_sec(<time>)` | Time to seconds |
| CONVERT_TZ | `convert_tz(<ts>, <from_tz>, <to_tz>)` | Timezone conversion |
| PERIOD_ADD | `period_add(<period>, <N>)` | Add months to period |
| PERIOD_DIFF | `period_diff(<p1>, <p2>)` | Months between periods |

## Conditional Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| ISNULL | `isnull(<expr>)` | True if NULL |
| ISNOTNULL | `isnotnull(<expr>)` | True if not NULL |
| ISPRESENT | `ispresent(<field>)` | True if field exists |
| ISEMPTY | `isempty(<field>)` | True if empty |
| ISBLANK | `isblank(<field>)` | True if blank |
| LIKE | `like(<field>, <pattern>)` | Pattern match |
| ILIKE | `ilike(<field>, <pattern>)` | Case-insensitive pattern |
| REGEXP_MATCH | `regexp_match(<field>, <pattern>)` | Regex match |
| CIDRMATCH | `cidrmatch(<ip>, <cidr>)` | CIDR match |
| JSON_VALID | `json_valid(<str>)` | Validate JSON |

## Flow Control Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| IF | `if(<cond>, <then>, <else>)` | Conditional |
| IFNULL | `ifnull(<val>, <default>)` | Null replacement |
| NULLIF | `nullif(<val1>, <val2>)` | Return null if equal |
| COALESCE | `coalesce(<val1>, <val2>, ...)` | First non-null |
| CASE | `case(<cond>, <val> [, <cond>, <val>]... [else <default>])` | Case expression |

## JSON Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| JSON | `json(<str>)` | Parse JSON |
| JSON_VALID | `json_valid(<str>)` | Validate JSON |
| JSON_OBJECT | `json_object(<key>, <val>, ...)` | Create object |
| JSON_ARRAY | `json_array(<val>, ...)` | Create array |
| JSON_ARRAY_LENGTH | `json_array_length(<arr>)` | Array length |
| JSON_EXTRACT | `json_extract(<json>, <path>)` | Extract value |
| JSON_KEYS | `json_keys(<json>)` | Get keys |
| JSON_SET | `json_set(<json>, <path>, <val>)` | Set value |
| JSON_DELETE | `json_delete(<json>, <path>)` | Delete key |
| JSON_APPEND | `json_append(<json>, <path>, <val>)` | Append to array |
| JSON_EXTEND | `json_extend(<json1>, <json2>)` | Extend object |

## Collection / Multivalue Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| ARRAY | `array(<val>, ...)` | Create array |
| ARRAY_LENGTH | `array_length(<arr>)` | Array length |
| MVAPPEND | `mvappend(<mv>, <val>)` | Append value |
| MVJOIN | `mvjoin(<mv>, <delim>)` | Join with delimiter |
| MVINDEX | `mvindex(<mv>, <idx>)` | Get value at index |
| MVFIND | `mvfind(<mv>, <regex>)` | Find matching index |
| MVDEDUP | `mvdedup(<mv>)` | Remove duplicates |
| MVZIP | `mvzip(<mv1>, <mv2> [, <delim>])` | Zip arrays |
| MVMAP | `mvmap(<mv>, <lambda>)` | Map function |
| SPLIT | `split(<str>, <delim>)` | Split string |
| FORALL | `forall(<arr>, <lambda>)` | All match predicate |
| EXISTS | `exists(<arr>, <lambda>)` | Any match predicate |
| FILTER | `filter(<arr>, <lambda>)` | Filter by predicate |
| TRANSFORM | `transform(<arr>, <lambda>)` | Transform elements |
| REDUCE | `reduce(<arr>, <init>, <lambda>)` | Reduce to single value |

## Cryptographic Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| MD5 | `md5(<str>)` | MD5 hash |
| SHA1 | `sha1(<str>)` | SHA-1 hash |
| SHA2 | `sha2(<str>, <bits>)` | SHA-2 hash |

## System Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| TYPEOF | `typeof(<expr>)` | Type of expression |

## Type Conversion

| Function | Signature | Description |
|----------|-----------|-------------|
| CAST | `cast(<expr> AS <type>)` | Type cast |
| TOSTRING | `tostring(<val>)` | To string |
| TONUMBER | `tonumber(<str>)` | To number |

### Cast Target Types
```
INT, INTEGER, LONG, DOUBLE, FLOAT, STRING, BOOLEAN, DATE, TIME, TIMESTAMP, IP, JSON
```

## Relevance / Full-Text Search Functions

| Function | Signature |
|----------|-----------|
| MATCH | `match(<field>, <query> [, <options>...])` |
| MATCH_PHRASE | `match_phrase(<field>, <query> [, <options>...])` |
| MATCH_PHRASE_PREFIX | `match_phrase_prefix(<field>, <query> [, <options>...])` |
| MATCH_BOOL_PREFIX | `match_bool_prefix(<field>, <query> [, <options>...])` |
| MULTI_MATCH | `multi_match([<fields>], <query> [, <options>...])` |
| SIMPLE_QUERY_STRING | `simple_query_string([<fields>], <query> [, <options>...])` |
| QUERY_STRING | `query_string([<fields>], <query> [, <options>...])` |

## IP Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| CIDRMATCH | `cidrmatch(<ip_field>, <cidr>)` | Match IP against CIDR |
| GEOIP | `geoip(<ip_field>)` | Geo-location lookup |
