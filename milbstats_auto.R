#!/usr/bin/env Rscript

# Automated MILB Stats Update Script
# This script can be scheduled to run daily using cron (Mac/Linux) or Task Scheduler (Windows)

library(tidyverse)
library(baseballr)
library(googlesheets4)

# Configuration
sheetslink <- 'GOOGLE_SHEETS_LINK'
LOG_FILE <- "milbstats_update.log"

# Logging function
log_message <- function(message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste(timestamp, message, sep = " - ")
  cat(log_entry, "\n")
  
  # Also write to log file
  write(log_entry, file = LOG_FILE, append = TRUE)
}

# Main update function
update_milb_stats <- function() {
  log_message("=== STARTING AUTOMATED MILB STATS UPDATE ===")
  
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
