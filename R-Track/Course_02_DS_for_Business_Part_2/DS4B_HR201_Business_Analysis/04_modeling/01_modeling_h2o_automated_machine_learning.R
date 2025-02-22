## HR_201_Employee_Attrition_Project
## Steven Ponce 2022

# H2O MODELING -----

# 1. Setup ----

# Load Libraries 
library(pacman)
p_load(h2o, recipes, readxl, tidyverse, tidyquant, stringr, forcats, cowplot, fs, glue)


# Load Data
path_train            <- (here::here('./R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/00_data/telco_train.xlsx'))
path_test             <- (here::here('./R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/00_data/telco_test.xlsx'))
path_data_definitions <- (here::here('./R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/00_data/telco_data_definitions.xlsx'))


train_raw_tbl         <- read_excel(path_train, sheet = 1)
test_raw_tbl          <- read_excel(path_test, sheet = 1)
definitions_raw_tbl   <- read_excel(path_data_definitions, sheet = 1, col_names = FALSE)


# Processing Pipeline
source(here::here('R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/00_scripts/data_processing_pipeline_rev1.R'))
train_readable_tbl <- process_hr_data_readable(train_raw_tbl, definitions_raw_tbl)
test_readable_tbl  <- process_hr_data_readable(test_raw_tbl, definitions_raw_tbl)


# ML Preprocessing 
recipe_obj <- recipe(Attrition ~ ., data = train_readable_tbl) %>%
    # remove zero variance
    step_zv(all_predictors()) %>%
    # factor variables
    step_mutate_at(JobLevel, StockOptionLevel, fn = factor) %>%
    prep()

recipe_obj

# bake
train_tbl <- bake(recipe_obj, new_data = train_readable_tbl)
test_tbl  <- bake(recipe_obj, new_data = test_readable_tbl)


# 2. Modeling ----
# * UPDATED AUTOML METHOD ---- 

# initialize
h2o.init()

# import a DF (or tibble) to an h2o cloud as an h20 frame.
as.h2o(train_tbl)
as.h2o(test_tbl)

# splitting the h2o DF into multiple DF's - validation DF
split_h2o <- h2o.splitFrame(as.h2o(train_tbl), ratios = c(0.85), seed = 1234)

# Training, Validation, ad Test data set
train_h2o <- split_h2o[[1]]   # 85%
valid_h2o <- split_h2o[[2]]   # 15%
test_h2o  <- as.h2o(test_tbl) 


# Specifying the columns 
# target - attrition 
# predictor - everything else 

y <- "Attrition"
x <- setdiff(names(train_h2o), y)  # all names except (y) attrition

# 
automl_models_h2o <- h2o.automl(
    x = x,
    y = y,
    training_frame   = train_h2o,    # training set (85%)
    # validation_frame = valid_h2o,  # validation set (15%)
    # leaderboard_frame = test_set,  # test set
    max_runtime_secs = 30,
    nfolds           = 5
)

typeof(automl_models_h2o)        # similar to class
slotNames(automl_models_h2o)     # get the names

automl_models_h2o@leaderboard    # summary of the model produced by automl
automl_models_h2o@leader         # leading, top model

# getting different models that are not the leader
h2o.getModel('StackedEnsemble_BestOfFamily_4_AutoML_1_20220712_64212')

automl_models_h2o@leaderboard %>% head(23)
h2o.getModel("DeepLearning_grid_1_AutoML_1_20220712_64212_model_1") 


# extract h20 model by position
# BEFORE - manual
automl_models_h2o@leaderboard %>% 
    as_tibble() %>% 
    slice(1) %>% 
    pull(model_id) %>% 
    h2o.getModel()

# AFTER - function
extract_h2o_model_name_by_position <- function(h2o_leaderboard, 
                                               n = 1,             # position 
                                               verbose = TRUE) {
    
    model_name <- h2o_leaderboard %>% 
        as_tibble() %>% 
        slice(n) %>% 
        pull(model_id) 
    
    if (verbose) message(model_name)
    
    return(model_name)
    
}  

# testing extract_h2o_model_name_by_position()
automl_models_h2o@leaderboard %>% 
    extract_h2o_model_name_by_position(n = 1) %>% 
    h2o.getModel()


# Saving Models 
# h2o.getModel("GLM_1_AutoML_3_20220715_102232") %>% 
#     h2o.saveModel(path = "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/")
# 
# h2o.getModel("StackedEnsemble_BestOfFamily_1_AutoML_3_20220715_102232") %>% 
#     h2o.saveModel(path = "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/")
# 
# h2o.getModel("DeepLearning_1_AutoML_3_20220715_102232") %>% 
#     h2o.saveModel(path = "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/")
 

# Loading Models
h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/GLM_1_AutoML_3_20220715_102232")

h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/StackedEnsemble_BestOfFamily_1_AutoML_3_20220715_102232")

h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/DeepLearning_1_AutoML_3_20220715_102232")   



# Making Predictions
# stacked_ensemble_h2o <- automl_models_h2o@leader

glm_h2o <- h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/GLM_1_AutoML_3_20220715_102232")

glm_h2o   

predictions <- h2o.predict(glm_h2o, newdata = as.h2o(test_tbl))

typeof(predictions)

predictions_tbl <- predictions %>% as_tibble()
predictions_tbl



deeplearning_h2o <- h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/DeepLearning_1_AutoML_3_20220715_102232")   

?h2o.deeplearning
deeplearning_h2o@allparameters


# 3. Visualizing The Leaderboard ----
data_transformed <- automl_models_h2o@leaderboard %>% 
    as_tibble() %>%
    mutate(model_type = str_split(model_id, "_", simplify = T)[,1]) %>% 
    slice(1:10) %>%
    rownames_to_column() %>%
    mutate(
        model_id   = as_factor(model_id) %>% reorder(auc),
        model_type = as.factor(model_type)
    ) %>%
    gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T) %>%
    mutate(model_id = paste0(rowname, ". ", model_id) %>% as_factor() %>% fct_rev()) 

data_transformed %>%
    ggplot(aes(x = value, y = model_id, color = model_type)) +
    geom_point(size = 3) +
    geom_label(aes(label = round(value, 2), hjust = "inward")) +
    facet_wrap(~ key, scales = "free_x") +
    theme_tq() +
    scale_color_tq() +
    labs(title = "H2O Leaderboard Metrics",
         subtitle = paste0("Ordered by: auc"),
         y = "Model Postion, Model ID", x = "")

 
h2o_leaderboard <- automl_models_h2o@leaderboard


# plot_h2o_leaderboard() - this function could be simplified using tidy eval
plot_h2o_leaderboard <- function(h2o_leaderboard, 
                                 order_by = c("auc", "logloss", "aucpr",
                                              "mean_per_class_error", "rmse", "mse"), 
                                 n_max = 20, 
                                 size = 4, 
                                 include_lbl = TRUE) {
    
    # Setup inputs
    order_by <- tolower(order_by[[1]])
    
    leaderboard_tbl <- h2o_leaderboard %>%
        as_tibble() %>%
        mutate(model_type = str_split(model_id, "_", simplify = T)[,1]) %>%
        rownames_to_column(var = "rowname") %>%
        mutate(model_id = paste0(rowname, ". ", as.character(model_id)) %>% as.factor())
    
    # Transformation
    if (order_by == "auc") {                                          
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(auc),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, 
                   -c(model_id, model_type, rowname), factor_key = T) 
        
    } else if (order_by == "logloss") {                                 
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(logloss) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)
        
    } else if (order_by == "logloss") {                                 
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(logloss) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)
        
    } else if (order_by == "aucpr") {                          
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(aucpr) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)    
        
    } else if (order_by == "mean_per_class_error") {                                
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(mean_per_class_error) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)
        
    } else if (order_by == "rmse") {     
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(rmse) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)
        
    } else if (order_by == "mse") {                                              
        
        data_transformed_tbl <- leaderboard_tbl %>%
            slice(1:n_max) %>%
            mutate(
                model_id   = as_factor(model_id) %>% reorder(mse) %>% fct_rev(),
                model_type = as.factor(model_type)
            ) %>%
            gather(key = key, value = value, -c(model_id, model_type, rowname), factor_key = T)    
        
    } else {
        stop(paste0("order_by = '", order_by, "' is not a permitted option."))
    }
    
    # Visualization
    g <- data_transformed_tbl %>%
        ggplot(aes(value, model_id, color = model_type)) +
        geom_point(size = size) +
        facet_wrap(~ key, scales = "free_x") +
        theme_tq() +
        scale_color_tq() +
        labs(title = "Leaderboard Metrics",
             subtitle = paste0("Ordered by: ", toupper(order_by)),
             y = "Model Postion, Model ID", x = "")
    
    if (include_lbl) g <- g + geom_label(aes(label = round(value, 2), hjust = "inward"))
    
    return(g)
    
} 

# Testing plot_h2o_leaderboard
automl_models_h2o@leaderboard %>%
    plot_h2o_leaderboard(order_by = "logloss")


# 4. BONUS: GRID SEARCH & CV ----

deeplearning_h2o <- h2o.loadModel('R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/DeepLearning_1_AutoML_3_20220715_102232')
deeplearning_h2o

test_tbl

h2o.performance(deeplearning_h2o, newdata = as.h2o(test_tbl))
## currently, the accuracy is 100-12.7 = 87.3
## can we improve the accuracy using grid search?

# |- Grid Search ----
?h2o.grid() 
?h2o.deeplearning
deeplearning_h2o@allparameters


deeplearning_grid_01 <- h2o.grid(
    algorithm = 'deeplearning',
    grid_id   = 'deeplearning_grid_01',
    
    # h2o.deeplearning()
    x                = x,    # predictors -age -> YearsWithCurrManager
    y                = y,    # target - Attrition
    training_frame   = train_h2o,
    validation_frame = valid_h2o,
    nfolds           = 5,
    
    # Hyperparamters: Use deeplearning_h2o@allparameters to see all
    hyper_params     = list(
        # Use some combinations (the first one was the original)
        hidden = list(c(10, 10, 10), c(50, 20, 10), c(20, 20, 20)),
        epochs = c(10, 50, 100)
    )
) 

deeplearning_grid_01

# examining the results
h2o.getGrid(grid_id = "deeplearning_grid_01", sort_by = "auc", decreasing = TRUE)


deeplearning_grid_01_model_3 <- h2o.getModel("deeplearning_grid_01_model_3")

deeplearning_grid_01_model_3 %>% h2o.auc(train = T, valid = T, xval = T)
# the model seem to be overfitting b/c the difference between training AUC and 
# the validation / cross validation AUC
#     train     valid      xval 
#   0.9993800 0.7827500 0.7531956 

deeplearning_grid_01_model_3 %>%
    h2o.performance(newdata = as.h2o(test_tbl))

 


# 5. Assessing Performance ----

deeplearning_h2o <- h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/DeepLearning_1_AutoML_3_20220715_102232")   

stacked_ensemble_h2o <- h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/StackedEnsemble_BestOfFamily_1_AutoML_3_20220715_102232")

glm_h2o <- h2o.loadModel("R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/GLM_1_AutoML_3_20220715_102232")



performance_h2o <- h2o.performance(stacked_ensemble_h2o, newdata = as.h2o(test_tbl))

typeof(performance_h2o)
performance_h2o %>% slotNames()

performance_h2o@metrics
  

# Classifier Summary Metrics
h2o.auc(performance_h2o, train = T, valid = T, xval = T)  
h2o.giniCoef(performance_h2o)  
h2o.logloss(performance_h2o)  

h2o.confusionMatrix(stacked_ensemble_h2o)
h2o.confusionMatrix(performance_h2o)

# Important measures that vary by threshold:

# F1: Optimal balance between precision and recall. Typically the threshold that maximizes F1 is used as threshold/ cutoff for turning class probability into 0/1. However, this is not always the best case! An expected value optimization is required when costs of false positives and false negatives are known.

# Precision: Measures false positives (e.g. predicted to leave but actually stayed)
 
# Recall: Measures false negatives (e.g. predicted to stay but actually left)
 
# True positives (tps), true negative (tns), false positives (fps) and false negatives (fns): Often converted to rates to understand the cost/benefit of a classifier. The rates are included as tpr, tnr, fpr and fnr.



# Precision vs Recall Plot 

# Precision = TP / (TP + FP)  It indicates how often we incorrectly say people will leave 
# when they actually will stay

# Recall = TP / (FN + TP)  It indicates how often we miss people that will leave by 
# incorrectly predicting they will stay. 

# In business context, recall i typically more important than precision.

# F1 score = 2 x [(precision * recall) / (precision + recall)]  It is a balance metrics
# We're interested in the Threshold that maximize the F1 Score 

performance_tbl <- performance_h2o %>%
    h2o.metric() %>%
    as_tibble() 
performance_tbl 

performance_tbl %>%
    filter(f1 == max(f1)) 

performance_tbl %>%
    ggplot(aes(x = threshold)) +
    geom_line(aes(y = precision), color = "blue", size = 1) +
    geom_line(aes(y = recall), color = "red", size = 1) +
    geom_vline(xintercept = h2o.find_threshold_by_max_metric(performance_h2o, "f1")) +
    theme_tq() +
    labs(title = "Precision vs Recall", y = "value")


# ROC Plot - receiver operating characteristic curve

path <- "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/DeepLearning_1_AutoML_3_20220715_102232"

load_model_performance_metrics <- function(path, test_tbl) {
    
    model_h2o <- h2o.loadModel(path)
    perf_h2o  <- h2o.performance(model_h2o, newdata = as.h2o(test_tbl)) 
    
    perf_h2o %>%
        h2o.metric() %>%
        as_tibble() %>%
        mutate(auc = h2o.auc(perf_h2o)) %>%
        select(tpr, fpr, auc)
    
} 

# we want to get the performance metrics for all three models
model_metrics_tbl <- fs::dir_info(path = "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/") %>%
    select(path) %>%
    mutate(metrics = map(path, load_model_performance_metrics, test_tbl)) %>%
    unnest(cols = metrics)


# tidydata & ROC plot 
model_metrics_tbl %>%
    mutate(
        # extract the model name
        path = str_split(path, pattern = "/", simplify = T)[,6] %>% as_factor(),
        # convert the auc values to factors so they can be used as labels
        auc  = auc %>% round(3) %>% as.character() %>% as_factor()
        ) %>% 
    
    ggplot(aes(x = fpr, y = tpr, color = path, linetype = auc)) +
    geom_line(size = 1) +
    theme_tq() +
    scale_color_tq() +
    theme(legend.direction = "vertical") +
    labs(
        title    = "ROC Plot",
        subtitle = "Performance of 3 Top Performing Models"
    )
 
# Precision vs Recall
load_model_performance_metrics <- function(path, test_tbl) {
    
    model_h2o <- h2o.loadModel(path)
    perf_h2o  <- h2o.performance(model_h2o, newdata = as.h2o(test_tbl)) 
    
    perf_h2o %>%
        h2o.metric() %>%
        as_tibble() %>%
        mutate(auc = h2o.auc(perf_h2o)) %>%
        select(tpr, fpr, auc, precision, recall) 
    
}

model_metrics_tbl <- fs::dir_info(path = "R-Track/Course_02_DS_for_Business_Part_2/DS4B_HR201_Business_Analysis/04_modeling/h2o_models/") %>%
    select(path) %>%
    mutate(metrics = map(path, load_model_performance_metrics, test_tbl)) %>%
    unnest(metrics)

model_metrics_tbl %>%                                                               
    mutate(
        path = str_split(path, pattern = "/", simplify = T)[,3] %>% as_factor(),
        auc  = auc %>% round(3) %>% as.character() %>% as_factor()
    ) %>%
    ggplot(aes(recall, precision, color = path, linetype = auc)) +
    geom_line(size = 1) +
    theme_tq() +
    scale_color_tq() +
    theme(legend.direction = "vertical") +
    labs(
        title    = "Precision vs Recall Plot",
        subtitle = "Performance of 3 Top Performing Models"
    )

  
# Gain & Lift

ranked_predictions_tbl <- predictions_tbl %>%
    bind_cols(test_tbl) %>%
    select(predict:Yes, Attrition) %>%
    arrange(desc(Yes))

## without the model we only expected an attrition of 1.6 pp or 16%
# How do we come up with 16%?
train_readable_tbl %>%
    rbind(test_readable_tbl) %>%
    group_by(Attrition) %>%
    summarize(n = n()) %>%
    ungroup() %>%   
    mutate(pct = n/sum(n)) %>%
    ungroup()

## For our test data the total number of expected quitters is 220 * 0.16 = 35.
## Gain: If 35 people expected to quit, we gained 9 of 35 or 25.7% in first 10 cases
## Lift: If expectation is 1.6 people, we beat the expectation by 9 / 1.6 = 5.6X in first 10 cases.

    
calculated_gain_lift_tbl <- ranked_predictions_tbl %>%
    mutate(ntile = ntile(Yes, n = 10)) %>%
    group_by(ntile) %>%
    summarise(
        cases     = n(),
        responses = sum(Attrition == "Yes")
    ) %>%
    arrange(desc(ntile)) %>%
    
    # add group numbers (opposite of ntile)
    mutate(group = row_number()) %>%
    select(group, cases, responses) %>%
    
    # calculations
    mutate(
        cumulative_responses = cumsum(responses),                             
        pct_responses        = responses / sum(responses),
        gain                 = cumsum(pct_responses),
        cumulative_pct_cases = cumsum(cases) / sum(cases),
        lift                 = gain / cumulative_pct_cases,
        gain_baseline        = cumulative_pct_cases,
        lift_baseline        = gain_baseline / cumulative_pct_cases
    )

calculated_gain_lift_tbl 

## ntile() breaks continuous value into “n” buckets or groups. This allows us to group the response (attrition) based on the ntile column.

## 10th Decile. This group had the highest class probability for leaving. 18 of 22 actually left.

gain_lift_tbl <- performance_h2o %>%
    h2o.gainsLift() %>%
    as_tibble()

# data transformation
gain_transformed_tbl <- gain_lift_tbl %>% 
    select(group, cumulative_data_fraction, cumulative_capture_rate, cumulative_lift) %>%
    select(-contains("lift")) %>%
    mutate(baseline = cumulative_data_fraction) %>%
    rename(gain     = cumulative_capture_rate) %>%
    # prepare the data for the plotting (for the color and group aesthetics)
    pivot_longer(cols      = c(gain, baseline), 
                 values_to = "value", 
                 names_to  = "key")


# gain chart
gain_transformed_tbl %>%
    ggplot(aes(x = cumulative_data_fraction, y = value, color = key)) +
    geom_line(size = 1.5) +
    scale_color_tq() +
    labs(
        title = "Gain Chart",
        x     = "Cumulative Data Fraction",
        y     = "Gain"
    ) + 
    theme_tq() 

# data transformation
lift_transformed_tbl <- gain_lift_tbl %>% 
    select(group, cumulative_data_fraction, cumulative_capture_rate, cumulative_lift) %>%
    select(-contains("capture")) %>%
    # the reason baseline is 1 is b/c the `cumulative_pct_cases` and `gain_baseline` are equal
    mutate(baseline = 1) %>%                               
    rename(lift     = cumulative_lift) %>%
    pivot_longer(cols      = c(lift, baseline), 
                 values_to = "value", 
                 names_to  = "key")


# lift chart
lift_transformed_tbl %>%
    ggplot(aes(x = cumulative_data_fraction, y = value, color = key)) +
    geom_line(size = 1.5) +
    scale_color_tq() +
    labs(
        title = "Lift Chart",
        x     = "Cumulative Data Fraction",
        y     = "Lift"
    ) + 
    theme_tq() 
  

# 5. Performance Visualization ----  

# Leaderboard Visualization
# Model Diagnostic Dashboard using the cowplot package

# Setup inputs
# adjust input so that all formats are working
h2o_leaderboard <- automl_models_h2o@leaderboard
newdata         <- test_tbl
order_by        <- "auc"
max_models      <- 4
size            <- 1

# arguments
plot_h2o_performance <- function(h2o_leaderboard, newdata, order_by = c("auc", "logloss"),
                                 max_models = 3, size = 1.5) {
    
    # Inputs
    leaderboard_tbl <- h2o_leaderboard %>%
        as_tibble() %>%
        slice(1:max_models)
    
    newdata_tbl <- newdata %>%
        as_tibble()
    
    order_by      <- tolower(order_by[[1]])
    order_by_expr <- rlang::sym(order_by)
    
    h2o.no_progress()   # turn off progress bar
    
    
    # 1. Model metrics 
    get_model_performance_metrics <- function(model_id, test_tbl) {
        
        model_h2o <- h2o.getModel(model_id)
        perf_h2o  <- h2o.performance(model_h2o, newdata = as.h2o(test_tbl))
        
        perf_h2o %>%
            h2o.metric() %>%
            as.tibble() %>%
            select(threshold, tpr, fpr, precision, recall)
        
    }
    
    model_metrics_tbl <- leaderboard_tbl %>%
        mutate(metrics = map(model_id, get_model_performance_metrics, newdata_tbl)) %>%
        unnest(metrics) %>%
        mutate(
            model_id = as_factor(model_id) %>% 
                # order by expression
                fct_reorder(!! order_by_expr, .desc = ifelse(order_by == "auc", TRUE, FALSE)),
            auc  = auc %>% 
                round(3) %>% 
                as.character() %>% 
                as_factor() %>% 
                fct_reorder(as.numeric(model_id)),
            logloss = logloss %>% 
                round(4) %>% 
                as.character() %>% 
                as_factor() %>% 
                fct_reorder(as.numeric(model_id))
        )
    
    
    # 1A. ROC Plot 
    p1 <- model_metrics_tbl %>%
        
        # `aes_string()` and `aes_()` are particularly useful when writing functions that create plots
        # because you can use strings or quoted names/calls to define the aesthetic mappings
        ggplot(aes_string("fpr", "tpr", color = "model_id", linetype = order_by)) +
        geom_line(size = size) +
        theme_tq() +
        scale_color_tq() +
        labs(title = "ROC", x = "FPR", y = "TPR") +
        theme(legend.direction = "vertical")
    
    
    # 1B. Precision vs Recall
    p2 <- model_metrics_tbl %>%
        ggplot(aes_string("recall", "precision", color = "model_id", linetype = order_by)) +
        geom_line(size = size) +
        theme_tq() +
        scale_color_tq() +
        labs(title = "Precision Vs. Recall", x = "Recall", y = "Precision") +
        theme(legend.position = "none")
     
    
    # 2. Gain / Lift 
    get_gain_lift <- function(model_id, test_tbl) {
        
        model_h2o <- h2o.getModel(model_id)
        perf_h2o  <- h2o.performance(model_h2o, newdata = as.h2o(test_tbl)) 
        
        perf_h2o %>%
            h2o.gainsLift() %>%
            as_tibble() %>%
            select(group, cumulative_data_fraction, cumulative_capture_rate, cumulative_lift)
        
    }
    
    gain_lift_tbl <- leaderboard_tbl %>%
        mutate(metrics = map(model_id, get_gain_lift, newdata_tbl)) %>%
        unnest(metrics) %>%
        mutate(
            model_id = as_factor(model_id) %>% 
                fct_reorder(!! order_by_expr, .desc = ifelse(order_by == "auc", TRUE, FALSE)),
            auc  = auc %>% 
                round(3) %>% 
                as.character() %>% 
                as_factor() %>% 
                fct_reorder(as.numeric(model_id)),
            logloss = logloss %>% 
                round(4) %>% 
                as.character() %>% 
                as_factor() %>% 
                fct_reorder(as.numeric(model_id))
        ) %>%
        rename(
            gain = cumulative_capture_rate,
            lift = cumulative_lift
            ) 
    
    
    # 2A. Gain Plot 
    p3 <- gain_lift_tbl %>%
        ggplot(aes_string(x = "cumulative_data_fraction", y = "gain", 
                          color = "model_id", linetype = order_by)) +
        geom_line(size = size) +
        # trick yo set up the baseline
        geom_segment(x = 0, y = 0, xend = 1, yend = 1, 
                     color = "black", size = size) +
        theme_tq() +
        scale_color_tq() +
        expand_limits(x = c(0, 1), y = c(0, 1)) +
        labs(title = "Gain",
             x = "Cumulative Data Fraction", y = "Gain") +
        theme(legend.position = "none")
    
    
    # 2B. Lift Plot
    p4 <- gain_lift_tbl %>%
        ggplot(aes_string(x = "cumulative_data_fraction", y = "lift", 
                          color = "model_id", linetype = order_by)) +
        geom_line(size = size) +
        # trick yo set up the baseline
        geom_segment(x = 0, y = 1, xend = 1, yend = 1, 
                     color = "black", size = size) +
        theme_tq() +
        scale_color_tq() +
        expand_limits(x = c(0, 1), y = c(0, 1)) +
        labs(title = "Lift",
             x = "Cumulative Data Fraction", y = "Lift") +
        theme(legend.position = "none")
    
    
    # Combine using cowplot
    p_legend <- cowplot::get_legend(p1)               # extract the legend from a ggplot object
    p1 <- p1 + theme(legend.position = "none")        # remove the legend from p1
    
    p <- cowplot::plot_grid(p1, p2, p3, p4, ncol = 2) # combine all 4 plots (2x1)
    
    # adding titles and subtitle
    p_title <- cowplot::ggdraw() + 
        cowplot::draw_label("H2O Model Metrics", size = 18, fontface = "bold", 
                   colour = palette_light()[[1]])
    
    p_subtitle <- cowplot::ggdraw() + 
        cowplot::draw_label(glue("Ordered by {toupper(order_by)}"), size = 10,  
                   colour = palette_light()[[1]])
    
    # Combine everything
    ret <- cowplot::plot_grid(p_title, p_subtitle, p, p_legend, 
                     ncol = 1, 
                     # Adjust the relative spacing, so that the legends always fits
                     rel_heights = c(0.05, 0.05, 1, 0.05 * max_models))  
    
    h2o.show_progress()
    
    return(ret)
    
}

# testing
automl_models_h2o@leaderboard %>%
    plot_h2o_performance(newdata = test_tbl, order_by = "logloss", 
                         size = 1, max_models = 4)




