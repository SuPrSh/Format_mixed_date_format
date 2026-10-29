# Format_mixed_date_format
R code for fixing mixed date formats in HOBO temperature logger data files.

## What the script does
Step 1: Fix dates       1.raw → 2.fixed         #Reads every logger CSV, detects the date format of each file and writes all dates as DD-MM-YYYY.
Step 2: Clean           2.fixed → 3.cleaned     #Removes readings logged while the loggers were out of the water (retrieval and redeployment).
Step 3: Daily summary   3.cleaned` → `4.daily   #Calculates daily minimum, mean and maximum temperature, and the number of readings per day.
Step 4: Plots           3.cleaned` → `5.plots   #Plots every reading with the daily mean.

## Folder structure
The script expects this layout. Each numbered folder has one sub-folder per logger retrieval (e.g. `JUN2025`).
```
Working dir/
├── fix_mixed_dates.R
├── README.md
├── 1.raw/          original logger exports (DO NOT EDIT)
├── 2.fixed/        Formatted dates
├── 3.cleaned/      Manual curation and trimming (if required)
├── 4.daily/        daily min / mean / max
└── 5.plots/        
```

## Requirements
- R (4.1 or later)
- Packages: `tidyverse`, `lubridate`

```r
install.packages(c("tidyverse", "lubridate"))
```

## How to use

1. Put the raw logger CSV files in `1.raw/<retrieval folder>/`.
2. Open `logger_processing.R` and set below lines:

```r
base_dir   <- "path/to/"            # folder containing 1.raw, 2.fixed, ...
master.dir <- "JUN2025"             # retrieval folder to process
header_row <- 2                     # line holding the column names in the raw files
```

3. Run the whole script (**Ctrl+Shift+Enter** in RStudio), or run one section at a time.

The output folders are created automatically. Each step prints how many files it processed and lists any files it skipped.

## Output columns

**Fixed and cleaned files**
| Column | Meaning |
|---|---|
| Old Date | Date and time exactly as written by the logger |
| Fixed Date (DD-MM-YY) | Date, DD-MM-YYYY |
| DD, MM, YYYY | Day, month and year |
| Time(HH:MM:SS) | Time, 24-hour clock |

**Daily files**
| Column | Meaning |
|---|---|
| Fixed Date (DD-MM-YY), DD, MM, YYYY | Date |
| N | Number of readings that day |
| Temp.min, Temp.mean, Temp.max | Daily minimum, mean and maximum temperature (°C) |

## Data
Logger data are not included in this repository.

## Author
Surya Sharma, Concordia University, Montreal, suryapdsharma@gmail.com

