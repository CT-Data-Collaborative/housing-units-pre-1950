library(dplyr)

##################################################################
#
# Processing Script for Housing Units Built Before 1950
# Created by Jenna Daly
# On 07/18/2017
#
##################################################################

#Setup environment
sub_folders <- list.files()
raw_location <- grep("raw", sub_folders, value=T)
path_to_raw_data <- (paste0(getwd(), "/", raw_location))
data_location <- grep("data$", sub_folders, value=T)
path_to_data <- (paste0(getwd(), "/", data_location))

housing_files <- dir(path_to_raw_data, recursive=T, pattern = "with_ann")
keep_cols <- c("Id2", "Geography", "^Estimate!!Total$", "^Estimate!!Total!!Built 1940 to 1949$", "^Estimate!!Total!!Built 1939 or earlier$")

housing_df <- data.frame(stringsAsFactors = F)
for (i in 1:length(housing_files)) {
  current_file <- read.csv(paste0(path_to_raw_data, "/", housing_files[i]), stringsAsFactors=F, header=T)
  colnames(current_file) = current_file[1, ] 
  current_file = current_file[-1, ]
  current_file <- current_file[,which(grepl(paste(keep_cols, collapse="|"), names(current_file)))]
  
  current_file$Year <- as.numeric(substr(unique(unlist(gsub("[^0-9]", "", unlist(housing_files[i])), "")), 1, 2)) + 2000

  housing_df <- rbind(housing_df, current_file)
}

housing_df

#cleanup geog names
housing_df$Geography <- sub(" town.*", "", housing_df$Geography)
housing_df$Geography <- sub(", Connecticut.*", "", housing_df$Geography)

#remove undefined towns
housing_df <- housing_df[!grepl("defined", housing_df$Geography),]

#Calculate units built before 1950
housing_df$`Housing Units Built Before 1950` <- NA
housing_df$`Estimate!!Total!!Built 1940 to 1949` <- as.numeric(housing_df$`Estimate!!Total!!Built 1940 to 1949`) 
housing_df$`Estimate!!Total!!Built 1939 or earlier` <- as.numeric(housing_df$`Estimate!!Total!!Built 1939 or earlier`)
housing_df$`Estimate!!Total` <- as.numeric(housing_df$`Estimate!!Total`)
housing_df$`Housing Units Built Before 1950` <- (housing_df$`Estimate!!Total!!Built 1940 to 1949` + housing_df$`Estimate!!Total!!Built 1939 or earlier`)

housing_df <- housing_df %>% 
  select(Id2, Year, Geography, `Estimate!!Total`, `Housing Units Built Before 1950`) %>% 
  rename(FIPS = Id2, `Town/County` = Geography, `Total Housing Units` = `Estimate!!Total`) %>% 
  arrange(`Town/County`, Year) %>% 
  mutate(`Percent Housing Units Built Before 1950` = round(((`Housing Units Built Before 1950` / `Total Housing Units`)*100), 1))

#Convert to Long format
cols_to_stack <- c("Total Housing Units", 
                   "Housing Units Built Before 1950", 
                   "Percent Housing Units Built Before 1950")           

long_row_count = nrow(housing_df) * length(cols_to_stack)

housing_df_long <- reshape(housing_df,
                           varying = cols_to_stack,
                           v.names = "Value",
                           timevar = "Variable",
                           times = cols_to_stack,
                           new.row.names = 1:long_row_count,
                           direction = "long"
)

housing_df_long$id <- NULL

#Assign Measure Type
housing_df_long$"Measure Type" <- "Number"
housing_df_long$"Measure Type"[which(grepl("Percent", housing_df_long$Variable))] <- "Percent"

#remove "Percent" from variable column
housing_df_long$Variable <- gsub("Percent ", "", housing_df_long$Variable)

#Assign town profile year
housing_df_long$`Town Profile Year` <- NA
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2013)] <- 2015
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2014)] <- 2016
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2015)] <- 2017
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2016)] <- 2018
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2017)] <- 2019
housing_df_long$`Town Profile Year`[which(housing_df_long$Year == 2018)] <- 2020

#Sort and select columns
housing_df_long <- housing_df_long %>% 
  select(`Town/County`, FIPS, Year, `Town Profile Year`, `Measure Type`, Variable, Value) %>% 
  arrange(`Town/County`, Year)

# Write to File
write.table(
  housing_df_long,
  file.path(getwd(), "data", "housing_units_built_before_1950-2020.csv"),
  sep = ",",
  row.names = F
)
