library(tidyverse)
library(baseballr)
library(googlesheets4)


sheetslink <- "https://docs.google.com/spreadsheets/d/1c8Y0IOksC6GcqqnHQiMgCpoRKIY2Ks6aHZcvrfmNzzc/edit?usp=sharing"

# Read the 'PlayerID' sheet into a data frame
playerid_data <- read_sheet(sheetslink, sheet = "PlayerID")

# Display the first few rows to verify the data
head(playerid_data)

# Create empty list to store dataframes
player_logs_list <- list()

# Loop through each player in playerid_data
for (i in 1:nrow(playerid_data)) {
  # Get current player's FG ID
  current_id <- playerid_data$fangraphs_id[i]
  
  # Get player name for reference
  player_name <- playerid_data$name[i]
  
  # Get player position
  player_position <- playerid_data$position[i]
  
  # Try to get game logs, with error handling
  tryCatch({
    # Get game logs based on position
    if (player_position == "H") {
      # Use batter game logs for position "H"
      player_logs <- fg_milb_batter_game_logs(as.character(current_id), 2023)
      print(paste("Retrieved BATTER logs for", player_name))
    } else {
      # Use pitcher game logs for other positions
      player_logs <- fg_milb_pitcher_game_logs(as.character(current_id), 2023)
      print(paste("Retrieved PITCHER logs for", player_name))
    }
    
    # Add to list with player name as identifier
    player_logs_list[[player_name]] <- player_logs
    
    # Print success message
    print(paste("Successfully retrieved logs for", player_name))
    
  }, error = function(e) {
    # Print error message if retrieval fails
    print(paste("Failed to retrieve logs for", player_name))
  })
  
  # Add small delay to avoid hitting API limits
  Sys.sleep(2)
}

# Debug: Print summary of what we retrieved
print("=== SUMMARY OF RETRIEVED DATA ===")
print(paste("Total players in list:", length(player_logs_list)))
print("Players with data:")
for (player_name in names(player_logs_list)) {
  player_data <- player_logs_list[[player_name]]
  if (!is.null(player_data) && nrow(player_data) > 0) {
    print(paste("-", player_name, ":", nrow(player_data), "rows"))
  } else {
    print(paste("-", player_name, ": NO DATA"))
  }
}

# Loop through each player's game logs and write to Google Sheets
for (player_name in names(player_logs_list)) {
  # Get the current player's data frame
  player_df <- player_logs_list[[player_name]]
  
  # Skip if data frame is empty or NULL
  if (is.null(player_df) || nrow(player_df) == 0) {
    print(paste("Skipping", player_name, "- no data available"))
    next
  }
  
  tryCatch({
    # Create a new sheet for the player
    # Clean player name to be sheet-friendly (remove special characters)
    sheet_name <- gsub("[^[:alnum:]]", "", player_name)
    
    # Write the data frame to a new sheet
    sheet_write(player_df, ss = sheetslink, sheet = sheet_name)
    
    print(paste("Successfully wrote data for", player_name, "to sheet:", sheet_name))
    
    # Add small delay to avoid API limits
    Sys.sleep(1)
    
  }, error = function(e) {
    print(paste("Failed to write data for", player_name, ":", e$message))
  })
}







