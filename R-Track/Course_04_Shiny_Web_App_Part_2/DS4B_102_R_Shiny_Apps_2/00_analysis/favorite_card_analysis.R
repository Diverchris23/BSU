# BUSINESS SCIENCE ----
# DS4B 202-R ----
# STOCK ANALYZER APP - FAVORITE CARD ANALYSIS -----
# Version 1

# APPLICATION DESCRIPTION ----
# - The user will select 1 stock from the SP 500 stock index
# - [DONE] The functionality is designed to pull the past 180 days of stock data 
# - We will cover the historic data to 2 moving averages - short (fast) and long (slow)
# - We will make a function to generate the moving average cards

# SETUP ----
library(tidyquant)
library(tidyverse)
library(shiny)

source(here::here("R-Track/Course_04_Shiny_Web_App_Part_2/DS4B_102_R_Shiny_Apps_2/00_scripts/stock_analysis_functions.R"))
source(here::here("R-Track/Course_04_Shiny_Web_App_Part_2/DS4B_102_R_Shiny_Apps_2/00_scripts/info_card.R"))

stock_list_tbl <- get_stock_list("SP500")

favorite_list_on_start <- c("AAPL", "GOOG", "NFLX")


# 1.0 Get Stock Data for Each Favorite ----
stock_data_favorites_tbl <- favorite_list_on_start %>% 
    map(get_stock_data) %>% 
    set_names(favorite_list_on_start)


# 2.0 Get Moving Average Data for Each Stock History ----
data <- stock_data_favorites_tbl$AAPL

get_stock_mavg_info <- function(data) {
    
    n_short <- data %>% pull(moving_avg_short) %>% is.na() %>% sum() + 1
    n_long  <- data %>% pull(moving_avg_long) %>% is.na() %>% sum() + 1
    
    data %>% 
        tail(1) %>% 
        mutate(
            moving_avg_warning_flag = moving_avg_short < moving_avg_long,
            n_short                 = n_short,
            n_long                  = n_long,
            pct_change              = (moving_avg_short - moving_avg_long) / moving_avg_long
        )
}

# testing get_stock_mavg_info()
stock_data_favorites_tbl %>%
    map_df(get_stock_mavg_info, .id = "stock")


# 3.0 Generate Favorite Card ----
favorites <- favorite_list_on_start 

generate_favorite_card <- function(data) {
    column(
        width = 3,
        info_card(
            title = as.character(data$stock),
            value = str_glue("{data$n_short}-Day <small>vs {data$n_long}-Day</small>") %>% HTML(),
            sub_value      = data$pct_change %>% scales::percent(accuracy = 0.1),
            sub_text_color = ifelse(data$moving_avg_warning_flag, "danger", "success"),
            sub_icon       = ifelse(data$moving_avg_warning_flag, "arrow_down", "arrow-up")
        )
    )
}



# 4.0 Generate All Favorite Cards in a TagList ----
generate_favorite_cards <- function(favorites,
                                    from = today() - days(180),
                                    to   = today(),
                                    moving_avg_short = 20,
                                    moving_avg_long  = 50){

favorites %>% 
    
    # Step 1 - pull the stock data and mavg calculations as a list
    map(.f = function(x) {
        
        x %>% 
            get_stock_data(
                from = from,
                to   = to,
                moving_avg_short = moving_avg_short,
                moving_avg_long  = moving_avg_long
            )
    }) %>% 
    
    set_names(favorites) %>% 
    
    # Step 2 - within each list, pull the last row 
    map(.f = function(data) {
        
        data %>% 
            get_stock_mavg_info()
    }) %>% 
    
    # Step 3 - stacks all the rows together 
    bind_rows(.id = "stock") %>% 
    mutate(stock = as_factor(stock)) %>%         # keep the order by using a factor
    split(.$stock) %>%                           # split into a list with the named stock
    
    # Step 4
    map(.f = function(data){
        data %>% generate_favorite_card()
        
    }) %>% 
    
    # Step 5
    tagList()
}


# Testing generate_favorite_cards()
generate_favorite_cards(favorites = c("NVDA", "AAPL"), 
                        from = "2018-01-01", 
                        to = "2019-01-01", 
                        moving_avg_short = 30,
                        moving_avg_long = 90)



# 5.0 Save Functions ----
dump(
    list = c("get_stock_mavg_info", "generate_favorite_card", 'generate_favorite_cards'), 
    file = "R-Track/Course_04_Shiny_Web_App_Part_2/DS4B_102_R_Shiny_Apps_2/00_scripts/generate_favorite_cards.R", append = FALSE)


