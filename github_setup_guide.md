# GitHub Actions Setup Guide for MILB Stats

## Why GitHub Actions?

✅ **Runs in the cloud** - No need for your computer to be on  
✅ **Free for public repos** - 2000 minutes/month free  
✅ **Easy monitoring** - See all runs in GitHub UI  
✅ **Manual triggers** - Can run anytime from GitHub  
✅ **Log storage** - Keeps logs for 30 days  
✅ **Reliable** - Runs on GitHub's servers  

## Step-by-Step Setup

### 1. Create GitHub Repository
```bash
# Initialize git in your current directory
git init
git add .
git commit -m "Initial commit: MILB stats automation"

# Create new repo on GitHub.com, then:
git remote add origin https://github.com/YOUR_USERNAME/milb-stats.git
git branch -M main
git push -u origin main
```

### 2. Set Up Google Sheets Authentication
Since GitHub Actions can't use interactive authentication, you need to set up service account:

1. **Go to Google Cloud Console**
   - Visit: https://console.cloud.google.com/
   - Create new project or select existing

2. **Enable Google Sheets API**
   - Go to "APIs & Services" > "Library"
   - Search for "Google Sheets API"
   - Click "Enable"

3. **Create Service Account**
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "Service Account"
   - Name: "milb-stats-automation"
   - Click "Create and Continue"

4. **Download JSON Key**
   - Click on your service account
   - Go to "Keys" tab
   - Click "Add Key" > "Create New Key"
   - Choose JSON format
   - Download the file

5. **Share Google Sheet**
   - Open your Google Sheet
   - Click "Share"
   - Add the service account email (from JSON file) with "Editor" access

### 3. Add Secrets to GitHub
1. Go to your GitHub repo
2. Click "Settings" > "Secrets and variables" > "Actions"
3. Click "New repository secret"
4. Add these secrets:

**GOOGLE_SERVICE_ACCOUNT_KEY**
- Name: `GOOGLE_SERVICE_ACCOUNT_KEY`
- Value: Copy the entire contents of your downloaded JSON file

### 4. Update Script for Service Account
Create `milbstats_github.R`:

```r
#!/usr/bin/env Rscript

library(tidyverse)
library(baseballr)
library(googlesheets4)

# Read service account key from environment
service_account_key <- Sys.getenv("GOOGLE_SERVICE_ACCOUNT_KEY")
if (service_account_key != "") {
  # Write key to temporary file
  temp_key_file <- tempfile(fileext = ".json")
  writeLines(service_account_key, temp_key_file)
  
  # Authenticate with service account
  gs4_auth(path = temp_key_file)
  
  # Clean up
  unlink(temp_key_file)
}

# Configuration
sheetslink <- "GOOGLE_SHEETS_LINK"
LOG_FILE <- "milbstats_update.log"

# Logging function
log_message <- function(message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste(timestamp, message, sep = " - ")
  cat(log_entry, "\n")
  write(log_entry, file = LOG_FILE, append = TRUE)
}

# Main update function
update_milb_stats <- function() {
  log_message("=== STARTING GITHUB ACTIONS MILB STATS UPDATE ===")
  
  tryCatch({
    # Read the PlayerID sheet
    log_message("Reading PlayerID sheet...")
    playerid_data <- read_sheet(sheetslink, sheet = "PlayerID")
    log_message(paste("Loaded", nrow(playerid_data), "players"))
    
    # Process each player
    success_count <- 0
    error_count <- 0
    
    for (i in 1:nrow(playerid_data)) {
      current_id <- playerid_data$fangraphs_id[i]
      player_name <- playerid_data$name[i]
      player_position <- playerid_data$position[i]
      
      log_message(paste("Processing", i, "of", nrow(playerid_data), ":", player_name))
      
      tryCatch({
        # Get game logs based on position
        if (player_position == "H") {
          player_logs <- fg_milb_batter_game_logs(as.character(current_id), 2023)
          log_message(paste("Retrieved BATTER logs for", player_name))
        } else {
          player_logs <- fg_milb_pitcher_game_logs(as.character(current_id), 2023)
          log_message(paste("Retrieved PITCHER logs for", player_name))
        }
        
        # Clean sheet name and write to Google Sheets
        sheet_name <- gsub("[^[:alnum:]]", "", player_name)
        sheet_write(player_logs, ss = sheetslink, sheet = sheet_name)
        
        log_message(paste("Successfully updated", player_name, "with", nrow(player_logs), "rows"))
        success_count <- success_count + 1
        
      }, error = function(e) {
        log_message(paste("ERROR: Failed to process", player_name, "-", e$message))
        error_count <- error_count + 1
      })
      
      # Add delay to avoid API limits
      Sys.sleep(2)
    }
    
    log_message(paste("=== UPDATE COMPLETE ==="))
    log_message(paste("Successfully updated:", success_count, "players"))
    log_message(paste("Errors:", error_count, "players"))
    
  }, error = function(e) {
    log_message(paste("CRITICAL ERROR:", e$message))
  })
}

# Run the update
update_milb_stats()
```

### 5. Update GitHub Actions Workflow
Update `.github/workflows/milbstats.yml`:

```yaml
name: MILB Stats Update

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC (10 PM EST)
  workflow_dispatch:  # Allows manual trigger from GitHub UI

jobs:
  update-stats:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
    
    - name: Set up R
      uses: r-lib/actions/setup-r@v2
      with:
        r-version: '4.2'
    
    - name: Install system dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
    
    - name: Install R packages
      run: |
        R -e "install.packages(c('tidyverse', 'baseballr', 'googlesheets4'), repos='https://cran.rstudio.com/')"
    
    - name: Run MILB stats update
      run: Rscript milbstats_github.R
      env:
        GOOGLE_SERVICE_ACCOUNT_KEY: ${{ secrets.GOOGLE_SERVICE_ACCOUNT_KEY }}
    
    - name: Upload log file as artifact
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: milbstats-logs-${{ github.run_number }}
        path: milbstats_update.log
        retention-days: 30
```

### 6. Push to GitHub
```bash
git add .
git commit -m "Add GitHub Actions automation"
git push
```

## Monitoring Your Automation

### View Runs
1. Go to your GitHub repo
2. Click "Actions" tab
3. See all scheduled and manual runs

### Manual Trigger
1. Go to "Actions" tab
2. Click "MILB Stats Update" workflow
3. Click "Run workflow" button
4. Click "Run workflow" to start immediately

### View Logs
1. Click on any run
2. Click on "update-stats" job
3. See detailed logs for each step
4. Download log artifacts

## Schedule Options

Change the cron schedule in `.github/workflows/milbstats.yml`:

```yaml
# Daily at 2 AM UTC (10 PM EST)
- cron: '0 2 * * *'

# Every 6 hours
- cron: '0 */6 * * *'

# Weekdays only at 8 AM UTC
- cron: '0 8 * * 1-5'

# Twice daily (2 AM and 2 PM UTC)
- cron: '0 2,14 * * *'
```

## Benefits of GitHub Actions

- **Always runs** - Even if your computer is off
- **No maintenance** - GitHub handles the infrastructure
- **Easy monitoring** - See all runs in one place
- **Free** - 2000 minutes/month for free accounts
- **Scalable** - Can handle multiple scripts easily

This is probably the most reliable option since it doesn't depend on your local machine being on! 
