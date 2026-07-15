# SeedPod Quick Log — CSV schema

Quick-log data is exported as **one CSV table per log type**, because each type
has its own set of fields. Every table shares the same first two columns
(`id`, `timestamp`), followed by that type's data columns.

- `id` — stable unique id (millisecond-epoch string by default).
- `timestamp` — ISO 8601 date-time (e.g. `2026-07-15T09:30:00.000`).
- All other cells are plain strings; empty means "not set".
- Files follow RFC 4180: fields containing a comma, double-quote, or line
  break are wrapped in double-quotes, and embedded quotes are doubled (`""`).

These schemas are the source of truth in code:
[`kCsvDataColumns`](../lib/models/log_io.dart). Conversion is handled by
`QuickLogIo.exportCsv` / `QuickLogIo.importCsv`.

| Type (`LogType.name`) | Columns (after `id, timestamp`) |
|-----------------------|----------------------------------|
| `growth`         | `weight_kg`, `height_cm`, `note` |
| `sleep`          | `start`, `end`, `note` |
| `feeding`        | `type`, `side`, `duration_min`, `amount_ml`, `note` |
| `milestone`      | `title`, `note` |
| `health`         | `title`, `note` |
| `nappy`          | `type`, `note` |
| `medication`     | `name`, `dose`, `note` |
| `food`           | `name`, `reaction`, `note` |
| `teeth`          | `tooth`, `note` |
| `memory`         | `title`, `note` |
| `appointment`    | `type`, `doctor`, `note` |
| `sleep_training` | `method`, `note` |
| `environment`    | `title`, `note` |
| `note`           | `title`, `note` |
| `photo`          | `title`, `note` |

## Field notes

- **feeding** — `type` ∈ {Breast, Bottle, Formula, Solids}; `side` ∈ {Left,
  Right} (only for Breast); `duration_min` for Breast, `amount_ml` otherwise.
- **sleep** — `start` / `end` are ISO 8601 date-times.
- **nappy** — `type` ∈ {Wet, Dirty, Both, Dry}.
- **food** — `reaction` ∈ {None, Mild, Severe}.

## Example — `growth.csv`

```csv
id,timestamp,weight_kg,height_cm,note
1721030400000,2026-07-15T09:30:00.000,5.2,58.5,"After morning feed"
```

On import, columns are matched **by header name**, so reordering columns or
adding extra unknown columns is tolerated; unknown columns are ignored.
