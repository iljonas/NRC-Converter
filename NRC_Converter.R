#Designed by: Isaac Jonas
#Email: iljonas@cmh.edu
#Phone: (816) 302-3786 (x: 73786)

#How to: This report is designed to be used with minimal user input on a Windows system. Before running this script,
#the user must download the results, encounters, and outcomes datasets from the NRC website for the appropriate 
#timeframe. The script assumes these downloads will be directed to the user's Downloads folder (C:\Users\USER\Downloads)
#and were downloaded on the same day that the script was run. If these conditions are all met, the script will export
#two csv files titled "Encounters" and "Responses", each followed by the current date in a yyyyMMdd format, to the 
#Downloads folder. From there, the Excel file prep and Access data upload can proceed as normal
#NOTE: This script requires the dplyr and lubridate libraries. If you don't have them already, use the install.packages()
#function to install them

#Purpose: This report is designed to map the new, renamed NRC fields to the original names designed to be used in the
#Access file while also stripping away the extra fields that could interfere with the file and would unnecessarily increase
#the file size and processing time. There are some instances where the field required more modifications than just renaming
#the header to get it back in line with the original downloads. Mostly this was due to the new datetime formats: the new
#datetime fields often add timezone modifiers, which are not innately recognized by Excel and are assumed to be strings, 
#and add 3 decimal places to seconds. On the fields that don't have a timezone modifier, these decimal places seem to 
#throw off Excel's assumptions on what to do with this time format, so only the hours, minutes, and seconds are displayed
#instead of the years, months, and days. To make sure this latter display issue didn't mess anything up in Access and to
#keep the data consistent with the previous datetime values that didn't have decimal places at all, the date is rounded to
#the nearest whole second. For the timezone issue, the as.POSIXlt function is used to convert the string into a date value,
#which can be modified and standardized from there. There are other modifications to the values as well, but those can be
#described on a case-by-case basis

#The script was ignoring the decimal places (effectively flooring them), so the decimal place for seconds was increased
#by 3, which is how it's set up in the csvs. The libraries are also called here. dplyr is used to make the data frame
#modifications more legible, and lubridate is used to round off the decimals in the dates
options(digits.secs = 3)
library(dplyr)
library(lubridate)

#The nrc.df function prepares reads the called for csv from the dest.file object, which contains all of the outcomes,
#encounter, and results files downloaded today. Because the dest.file object stores the file pathway as a row name, and
#dplyr defaults all row names to their placement value (1, 2, 3, etc.), dplyr could not be used to modify these values,
#except for the pipline character, which doesn't rename the rows. First the function identifies the row whose row name
#matches the provided pattern (programmed to be the beginning of the file name that's needed, such as 'encounter_') from
#the parameter. In case there are multiple matches, the rows are then ordered based on their last modification time. The
#first row is then selected, the name of that row (which is the file name) is isolated, and then the file name is fed into
#the read.csv function to read it into R
nrc.df <- function(reg.pattern){
     dest.file[grep(reg.pattern, rownames(dest.file)), ] %>%
          .[order(.$mtime, decreasing = TRUE), ] %>%
          .[1, ] %>%
          rownames %>%
          read.csv
}

#The date.format function formats datetime strings as dates, rounds off the seconds, and reformats as strings. If the
#TZ data.type is used, the string includes the timezone and the as.POSIXlt function is needed to set it to central
#standard time; otherwise the as.Date function is used
date.format <- function(date.string, date.type){
     if (date.type == "TZ") {
          date.string.formatted <- as.POSIXlt(date.string, "America/Chicago", "%Y-%m-%dT%H:%M:%OS")
     } else {
          date.string.formatted <- as.Date(date.string)
     }
     round_date(date.string.formatted, unit = "seconds") %>%
          format("%Y-%m-%d %H:%M:%S")
}

#The outreach.type.conversion function converts the revised approach to storing the outreach type, where it's now a numeric
#value, to the original approach, which is a string describing the outreach. Because the outcomes file stores all outreach
#attempts and the results file only stores the last one needed to obtain a result, different requirements are needed depending
#on where the value is coming from. The most recent outreach type is determined by taking the maximum value of the 
#outreachattempt_id, which is sequential, and the outreachattempt_surveymethod. If the length of the string is greater than 1,
#then the outreachattempt_id must be present and needs to be removed. Otherwise only the outreachattempt_surveymethod itself
#was passed (as is the case with the results file because it's already the most recent), so this step isn't needed. After
#that, the outreach.value is lined up with its corresponding string value, which is returned
outreach.type.conversion <- function(outreach.value){
     char.length <- nchar(outreach.value)
     if(char.length > 1) {
          outreach.value <- substr(outreach.value, char.length, char.length)
     }

     if (outreach.value == '4') {
          return('IVR')
     } else if (outreach.value == '1') {
          return('Email')
     } else if (outreach.value == '2') {
          return('SMS')
     } else {
          return('Unknown Value')
     }
}

#The write.to.folder function generates the folder pathway (based on the current user) to the Downloads folder and
#names the file after the provided file name combined with the day that this script was run. It also includes additional
#parameters to specify that it's comma separated, NA values should be replaced with blanks, and row names shouldn't be
#included
write.to.folder <- function(df, file.name){
     write.table(df, 
                 paste0("C:\\Users\\", Sys.info()[["user"]], "\\Downloads\\", file.name, current.day, ".csv"), 
                 sep = ",", na = "", row.names = FALSE)
}

#The dest.file data frame contains all files the user's Downloads folder that start with either result, encounter, or
#outreachattempt, followed by an underscore and the current day. The initial collection of these specific files is
#obtained with the list.files function, and that list is then used to collect information about these files via the
#file.info function, which produces the data frame
current.day <- format(Sys.Date(), "%Y%m%d")
dest.file <- list.files(paste("C:\\Users", Sys.info()[["user"]], "Downloads", sep = "\\"),
                        pattern = paste0("^(result|encounter|outreachattempt)_", current.day), 
                        full.names = TRUE) %>%
     file.info

#Reads the result file into R using the nrc.df function and transmutes the columns to match the original formatting of
#the responses file. For most this just means changing the column names, but for the datetime values and a few other
#additional adjustments need to be made. The transmute function was used because it only keeps those values you select to 
#modify; all other columns are removed. For the datetime values, they are either identified as "TZ", meaning they contain
#Timezone information, or "Unadjusted" meaning that they don't. All other adjustments are described where they occur in
#the script
result.df <- nrc.df("result_") %>%
     transmute(Address = person_address,
               City = person_city,
               CompleteDate = date.format(outreachattempt_completedate, "TZ"),
               DischargeDr = medicalvisit_dischargedr,
               DOB = date.format(as.character(person_dob), "Unadjusted"),
               Gender = person_gender,
               #The new language field is all capital letters, while the original only capitalized the first letter.
               #This script separates the first and following letters, makes the second part lowercase, and recombines them
               Language = paste0(toupper(substr(person_language, 1, 1)), 
                                 tolower(substr(person_language, 2, length(person_language)))),
               Location = location_name,
               MaritalStatus = person_maritalstatus,
               MRN = medicalvisit_mrn,
               NRCEncounterID = medicalvisit_id,
               OutreachDate = date.format(outreachattempt_sendondate, "TZ"),
               #The outreach.type.conversion function can only apply to string at a time, not an entire column. So the
               #sapply function is used to loop through the entire outreachattempt_surveymethod column and apply each row
               #to the function
               OutreachType = sapply(.$outreachattempt_surveymethod, outreach.type.conversion),
               Passthru01 = passthru_01,
               Passthru02 = passthru_02,
               Passthru03 = passthru_03,
               Passthru04 = passthru_04,
               Passthru05 = passthru_05,
               Passthru06 = passthru_06,
               Passthru07 = passthru_07,
               Passthru08 = passthru_08,
               Passthru09 = passthru_09,
               Passthru10 = passthru_10,
               #Combines the first and last name, separated by a space
               PatientName = paste(person_firstname, person_lastname, sep = " "),
               QuestionID = question_id,
               QuestionText = question_text,
               Race = person_race,
               #Replaces each instance of 'NaN' with '999', which was the original replacement for any erroneous or otherwise
               #unusable IDs. This not only keeps the data consistent, but Excel and Access will treat NaN, and therefore the
               #rest of the column, as a string instead of a number
               ResponseID = as.numeric(replace(as.character(scalevalue_ordinal), scalevalue_ordinal == 'NaN', '999')),
               ResponseText = scalevalue_text,
               SpecialtyPassthru = specialtypassthru,
               State = person_state,
               Survey = questionpod_name,
               VisitDate = date.format(medicalvisit_dischargedate, "TZ"),
               VisitType = medicalvisit_visittype,
               Zip = person_zip)

#Reads the outreachattempt file into R using the nrc.df function and transmutes the columns to match the original formatting 
#of the encounters file. For most this just means changing the column names, but for the datetime values and a few other
#additional adjustments need to be made. The transmute function was used because it only keeps those values you select to 
#modify; all other columns are removed. For the datetime values, they are either identified as "TZ", meaning they contain
#Timezone information, or "Unadjusted" meaning that they don't. All other adjustments are described where they occur in
#the script. Because the original encounters file only showed the most recent outreach attempt and the outreachattempt file
#shows all attempts, the table is grouped on its NRCEncounterID, which occurs only once per encounter, and the max value of
#the OutreachDate, CompleteDate, and OutreachType is obtained for each ID via the summarize function.
#na.rm is used so that the presence of NAs doesn't cause the the max function to just return an NA regardless of any dates
#present. This results in warnings for IDs where only NAs are present, but otherwise the function works as intended. 
#Finally, the mutate function is used to adjust the Outreach function to exclude the outreachattempt_id and equate the
#numeric survey method value with its string counterpart (which can only be done one value at a time, which is why the sapply
#loop function is applied over the OutreachType column) without removing all of the other columns, which is what happens with
#the transmute function
outcomes.df <- nrc.df("outreachattempt_") %>%
     transmute(NRCEncounterID = medicalvisit_id,
               CompleteDate = date.format(outreachattempt_completedate, "TZ"),
               #Formerly this field was just a TRUE/FALSE description of if the survey had ben completed or not. The TRUEs
               #in the original line up with only 'Survey Complete' in the current version, so all others are considered FALSE
               IsReturned = ifelse(outreachattempt_currentstatusdescription == 'Survey Complete', 'TRUE', 'FALSE'),
               OutreachDate = date.format(outreachattempt_sendondate, "TZ"),
               #Only the most recent outreachattempt_surveymethod is needed, and the other datetime fields that contain
               #unique times for each outreach attempt are often NULL. Because of this and outreachattempt_id is sequential,
               #it is used to identify the most recent outreach attempt instead of a date field
               AllOutreachType = paste0( outreachattempt_id, "_", outreachattempt_surveymethod )) %>%
     group_by(NRCEncounterID) %>%
     summarize(OutreachDate = max(OutreachDate, na.rm = TRUE), CompleteDate = max(CompleteDate, na.rm = TRUE),
               IsReturned = max(IsReturned, na.rm = TRUE), OutreachType = max(AllOutreachType, na.rm = TRUE)) %>%
     mutate(OutreachType = sapply(.$OutreachType, outreach.type.conversion))

#Reads the encounter file into R using the nrc.df function and transmutes the columns to match the original formatting 
#of the encounters file. For most this just means changing the column names, but for the datetime values and a few other
#additional adjustments need to be made. The transmute function was used because it only keeps those values you select to 
#modify; all other columns are removed. For the datetime values, they are either identified as "TZ", meaning they contain
#Timezone information, or "Unadjusted" meaning that they don't. All other adjustments are described where they occur in
#the script. The original encounters file contained outcomes information, which is now stored in the outcomeattempts file.
#To obtain this information, the results of the transmuted encounter file are merged with the already transmuted outreach
#file on the NRCEncounterID field. The outreach file already contains only the maximum results for each field to match the
#contents of the original encounter file. The merger throws off the order of the fields by putting NRCEncounterID at the 
#beginning and the outreach data at the end, which doesn't match the original outline. The select statement is used to
#reorder these columns to match the original outline
encounter.df <- nrc.df("encounter_") %>%
     transmute(Address = person_address,
               City = person_city,
               DischargeDr = medicalvisit_dischargedr,
               DOB = date.format(as.character(person_dob), "Unadjusted"),
               Gender = person_gender,
               #The new language field is all capital letters, while the original only capitalized the first letter.
               #This script separates the first and following letters, makes the second part lowercase, and recombines them
               Language = paste0(toupper(substr(person_language, 1, 1)), 
                                 tolower(substr(person_language, 2, length(person_language)))),
               Location = location_name,
               MaritalStatus = person_maritalstatus,
               MRN = medicalvisit_mrn,
               NRCEncounterID = medicalvisit_id,
               Passthru01 = passthru_01,
               Passthru02 = passthru_02,
               Passthru03 = passthru_03,
               Passthru04 = passthru_04,
               Passthru05 = passthru_05,
               Passthru06 = passthru_06,
               Passthru07 = passthru_07,
               Passthru08 = passthru_08,
               Passthru09 = passthru_09,
               Passthru10 = passthru_10,
               #Combines the first and last name, separated by a space
               PatientName = paste(person_firstname, person_lastname, sep = " "),
               Race = person_race,
               SpecialtyPassthru = specialtypassthru,
               State = person_state,
               Survey = questionpod_name,
               VisitDate = date.format(medicalvisit_dischargedate, "TZ"),
               VisitType = medicalvisit_visittype,
               Zip = person_zip) %>%
     merge(outcomes.df, by = "NRCEncounterID") %>%
     select(Address, City, CompleteDate, DischargeDr:Gender, IsReturned, Language:MRN, NRCEncounterID,
            OutreachDate, OutreachType, Passthru01:Zip)

#Writes the resulting encounter and results data frames (outcomes isn't needed because it's merged with the encounter table)
#to new csv files in the Downloads folder
write.to.folder(result.df, "Responses_")
write.to.folder(encounter.df, "Encounters_")