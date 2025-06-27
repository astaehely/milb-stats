# Automated MILB Stats Scheduling Guide

## Option 1: Mac/Linux (cron)

### Step 1: Make the script executable
```bash
chmod +x milbstats_auto.R
```

### Step 2: Set up cron job
Open terminal and run:
```bash
crontab -e
```

Add one of these lines:

**Daily at 2 AM:**
```bash
0 2 * * * cd /Users/aaronstaehely/Documents/Sabermetrics\ work/Test\ MILB\ stats && Rscript milbstats_auto.R
```

**Every 6 hours:**
```bash
0 */6 * * * cd /Users/aaronstaehely/Documents/Sabermetrics\ work/Test\ MILB\ stats && Rscript milbstats_auto.R
```

**Weekdays only at 8 AM:**
```bash
0 8 * * 1-5 cd /Users/aaronstaehely/Documents/Sabermetrics\ work/Test\ MILB\ stats && Rscript milbstats_auto.R
```

### Step 3: Check if cron is running
```bash
sudo launchctl load -w /System/Library/LaunchDaemons/com.vix.cron.plist
```

## Option 2: Windows Task Scheduler

### Step 1: Create a batch file
Create `run_milbstats.bat`:
```batch
@echo off
cd "C:\Users\YourUsername\Documents\Sabermetrics work\Test MILB stats"
Rscript milbstats_auto.R
pause
```

### Step 2: Set up Task Scheduler
1. Open Task Scheduler (search in Start menu)
2. Click "Create Basic Task"
3. Name: "MILB Stats Update"
4. Trigger: Daily
5. Start time: 2:00 AM
6. Action: Start a program
7. Program: `C:\Users\YourUsername\Documents\Sabermetrics work\Test MILB stats\run_milbstats.bat`
8. Finish

## Option 3: RStudio with taskscheduleR

### Step 1: Install taskscheduleR
```r
install.packages("taskscheduleR")
```

### Step 2: Create scheduling script
```r
library(taskscheduleR)

# Schedule daily at 2 AM
taskscheduler_create(
  taskname = "MILB_Stats_Update",
  rscript = "milbstats_auto.R",
  schedule = "DAILY",
  starttime = "02:00",
  startdate = format(Sys.Date(), "%Y/%m/%d")
)
```

## Option 4: GitHub Actions (Cloud-based)

Create `.github/workflows/milbstats.yml`:
```yaml
name: MILB Stats Update

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:  # Manual trigger

jobs:
  update-stats:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up R
      uses: r-lib/actions/setup-r@v1
      with:
        r-version: '4.2'
    
    - name: Install packages
      run: |
        R -e "install.packages(c('tidyverse', 'baseballr', 'googlesheets4'))"
    
    - name: Run update script
      run: Rscript milbstats_auto.R
      env:
        GITHUB_PAT: ${{ secrets.GITHUB_PAT }}
```

## Monitoring and Logs

The script creates a log file `milbstats_update.log` that tracks:
- When updates start/complete
- Which players were processed
- Success/error counts
- Any errors that occurred

### Check logs:
```bash
# View recent logs
tail -f milbstats_update.log

# View today's logs
grep "$(date +%Y-%m-%d)" milbstats_update.log
```

## Troubleshooting

### Common Issues:
1. **Path issues**: Make sure the working directory is correct
2. **R not found**: Ensure R is in your system PATH
3. **Permission issues**: Make sure the script is executable
4. **Google Sheets auth**: May need to re-authenticate periodically

### Test the script manually first:
```bash
cd /path/to/script
Rscript milbstats_auto.R
```

### Check cron logs:
```bash
# Mac
sudo grep CRON /var/log/system.log

# Linux
sudo grep CRON /var/log/syslog
```

## Recommended Schedule

For MILB stats, I recommend:
- **Daily at 2 AM**: Most games end by midnight, so 2 AM ensures fresh data
- **Weekdays only**: If you only need regular season updates
- **Every 6 hours**: If you want near real-time updates during active periods

The script includes built-in delays to respect API rate limits, so it's safe to run frequently. 