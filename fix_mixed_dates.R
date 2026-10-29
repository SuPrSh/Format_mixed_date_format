library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidyverse)
library(tibble) 

#---path to main directory
base_dir   <- "path/to/base"
master.dir <- "JUL2027"        #dir containing raw csv files

#---paths
raw_dir    <- file.path(base_dir, "1.raw",   master.dir)  # raw CSV files
fixed_dir   <- file.path(base_dir, "2.fixed", master.dir) # fixed files
clean_dir <- file.path(base_dir, "3.cleaned", master.dir)  
daily_dir <- file.path(base_dir, "4.daily", master.dir)   # daily files
plot_dir  <- file.path(base_dir, "5.plots",   master.dir) # plots

#----create directories
dir.create(fixed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(daily_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

#----STEP 1.fix date
#-- check raw file format
Date_col_header <- "Date"   # start of the date-time column name
header_row      <- 2        # line number where the column names are (NA = auto-detect)

#--read CSV files from 1.raw
files <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
basename(files); length(files)

#-- run fix-date loop: raw_dir -> fixed_dir
n <- 0
for (f in files) {
  tryCatch({
    top <- read_lines(f, n_max = 30)
    hdr <- if (!is.na(header_row)) header_row else
      which(str_detect(top, paste0("^\\W*", Date_col_header)))[1]
    if (is.na(hdr)) { message("SKIPPED (no Date header): ", basename(f)); next }
    
    dat <- read_csv(f, skip = hdr - 1, col_types = cols(.default = col_character()),
                    comment = "", name_repair = "minimal", show_col_types = FALSE)
    
    dt_col   <- names(dat)[str_detect(names(dat), paste0("^", Date_col_header))][1]
    temp_col <- names(dat)[str_detect(names(dat), "^Temp")][1]
    pres_col <- names(dat)[str_detect(names(dat), "^Abs Pres")][1]
    if (is.na(dt_col) || is.na(temp_col)) {
      message("SKIPPED (Date or Temp column not found): ", basename(f)); next
    }
    raw_dates <- dat[[dt_col]]
    
    # decide the date order for this file
    if (any(str_detect(raw_dates, "^\\d{4}-"), na.rm = TRUE)) {
      file_orders <- c("ymd HMS", "ymd HM")                      # ISO: 2018-06-27T07:00:00Z
    } else {
      first_nums  <- as.integer(str_extract(raw_dates, "^\\d+"))
      file_orders <- if (any(first_nums > 12, na.rm = TRUE)) c("dmY HMS", "dmY HM", "dmy IMS p")
      else                                    c("mdY HMS", "mdY HM", "mdy IMS p")
    }
    parsed <- parse_date_time(raw_dates, orders = file_orders, tz = "UTC", quiet = TRUE)
    
    # pressure -> kPa (psi * 6.894757); blank if the file has no pressure column
    pres <- if (is.na(pres_col)) NA_real_ else {
      p <- suppressWarnings(as.numeric(dat[[pres_col]]))
      if (str_detect(pres_col, regex("psi", ignore_case = TRUE))) p * 6.894757 else p
    }
    
    out <- tibble(`Old Date`              = raw_dates,
                  `Fixed Date (DD-MM-YY)` = format(parsed, "%d-%m-%Y"),
                  DD                      = as.integer(format(parsed, "%d")),
                  MM                      = as.integer(format(parsed, "%m")),
                  YYYY                    = as.integer(format(parsed, "%Y")),
                  `Time(HH:MM:SS)`        = format(parsed, "%H:%M:%S"),
                  Temp.celcius            = suppressWarnings(as.numeric(dat[[temp_col]])),
                  Pres.kPa                = pres)
    
    write_csv(out, file.path(fixed_dir, paste0(tools::file_path_sans_ext(basename(f)), "_fixed.csv")),
              na = "")
    n <- n + 1
    message("Done: ", basename(f), "  (", sum(is.na(parsed)), " unparsed dates)")
  },
  error = function(e) message("FAILED: ", basename(f), " -> ", conditionMessage(e)))
}
cat(n, "of", length(files), "files converted\n")

####--STEP 1 done--####

#----STEP 2.daily summary 
#Before running daily summary, clean/trim the fixed files (see readme#5)
#--read CSV files from 3.cleaned
files <- list.files(clean_dir, pattern = "\\.csv$", full.names = TRUE)
cat(length(files), "files found in", clean_dir, "\n")
n <- 0
for (f in files) {
  tryCatch({
    o <- read_csv(f, col_types = cols(.default = "c"))
    
    daily <- tibble(Date = dmy(o$`Fixed Date (DD-MM-YY)`, quiet = TRUE),
                    temp = as.numeric(o$Temp.celcius)) |>
      filter(!is.na(Date), !is.na(temp)) |>
      group_by(Date) |>
      summarise(N         = n(),
                Temp.min  = round(min(temp),  2),
                Temp.mean = round(mean(temp), 2),
                Temp.max  = round(max(temp),  2)) |>
      mutate(`Fixed Date (DD-MM-YY)` = format(Date, "%d-%m-%Y"),
             DD = day(Date), MM = month(Date), YYYY = year(Date), .before = 1) |>
      select(-Date)
    
    if (nrow(daily) == 0) stop("no valid rows")
    
    write_csv(daily, file.path(daily_dir, sub("\\.csv$", "_daily.csv", basename(f))), na = "")
    n <- n + 1
  },
  error = function(e) message("ERROR ", basename(f), ": ", conditionMessage(e)))
}
cat(n, "of", length(files), "files summarised\n")
####--STEP 2 done--####

#----STEP 3.Create plots
n <- 0
for (f in files) {
  tryCatch({
    o  <- read_csv(f, col_types = cols(.default = "c"))
    d  <- dmy(o$`Fixed Date (DD-MM-YY)`, quiet = TRUE)
    dt <- dmy_hms(paste(o$`Fixed Date (DD-MM-YY)`, o$`Time(HH:MM:SS)`), quiet = TRUE, tz = "UTC")
    dt[is.na(dt)] <- as.POSIXct(d[is.na(dt)], tz = "UTC") + hours(12)     # no time -> midday
    
    pts <- tibble(dt, day = d, temp = as.numeric(o$Temp.celcius)) |>
      filter(!is.na(dt), !is.na(temp))
    if (nrow(pts) == 0) stop("no valid rows")
    
    daily <- pts |>
      group_by(day) |>
      summarise(temp = mean(temp)) |>
      complete(day = seq(min(day), max(day), by = "day")) |>               # gaps for missing days
      mutate(dt = as.POSIXct(day, tz = "UTC") + hours(12))
    
    r    <- range(pts$dt)
    site <- sub("\\.csv$", "", basename(f))
    
    g <- ggplot() +
      geom_point(data = pts, aes(dt, temp), shape = 1, size = 1, colour = "#4472C4", alpha = 0.4) +
      geom_line(data = daily, aes(dt, temp), colour = "grey35", linewidth = 0.5, na.rm = TRUE) +
      scale_x_datetime(breaks = c(r[1], mean(r), r[2]), date_labels = "%d-%m-%Y",
                       expand = expansion(mult = 0.03)) +
      labs(title = site, x = NULL, y = "Temperature (°C)") +
      theme_minimal(base_size = 12) +
      theme(plot.title = element_text(hjust = 0.5), panel.grid.minor = element_blank())
    
    ggsave(file.path(plot_dir, paste0(site, "_temp.png")), g, width = 9, height = 5, dpi = 300)
    n <- n + 1
  },
  error = function(e) message("ERROR ", basename(f), ": ", conditionMessage(e)))
}
cat(n, "of", length(files), "files plotted\n")
####--STEP 3 done--####

