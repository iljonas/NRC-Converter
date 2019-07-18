#Designed by: Isaac Jonas
#Email: iljonas@cmh.edu
#Phone: (816) 302-3786 (x: 73786)

#How to: This report is designed to be used with minimal user input on a Windows system. Before running this script,
#the user must download the results, encounters, and outcomes datasets from the NRC website for the appropriate 
#timeframe. The script assumes these downloads will be directed to the user's Downloads folder (C:\Users\USER\Downloads)
#and were downloaded on the same day that the script was run. If these conditions are all met, the script will export
#two csv files titled "Encounters" and "Responses", each followed by the current date in a yyyyMMdd format, to the 
#Downloads folder. From there, the Excel file prep and Access data upload can proceed as normal
#NOTE: This script requires the dplyrlibrary. If you don't have them already, use the install.packages() function to 
#install them

#Purpose: This report is designed to map the new, renamed NRC fields to the original names designed to be used in the
#Access file while also stripping away the extra fields that could interfere with the file and would unnecessarily increase
#the file size and processing time. There are some instances where the field required more modifications than just renaming
#the header to get it back in line with the original downloads. These modifications will be described on a case-by-case 
#basis within the script

#The libraries are called here. dplyr is used to make the data frame modifications more legible, and lubridate is used to
#convert dates to strings without leading zeroes in the month, day, and hour positions, which is how the dates are set up in
#the source datasets
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

#Nurse Advice Line entries don't provide a financial number (FIN), so a placeholder is provided that consists of a dash, the 
#date of the call, and the patient MRN. This string is too long for the Access upload, which only allows for 15 characters
#max. For these entries, the string is reformatted to have no dash and a much shorter date string (yymmdd). To accomplish
#this, the two fields that compose this placeholder value, medicalvisit_dichargedate and medicalvisit_mrn, are formatted
#and combined to create a shorter version of the string. First the discharge date is converted from a string to POSIXct, 
#and then that date value is converted back into a 6 character string (yyMMdd). This value is then appended with the MRN
FIN.formatted <- function(discharge.date, MRN){
     discharge.date %>% 
          as.POSIXct(format = "%m/%d/%Y %H:%M:%S") %>%
          format('%y%m%d') %>%
          paste0(MRN)
}

#The date.to.string function takes a datetime value and converts it into a string. Because the format() function in base R
#always adds leading zeros to months, days, and hours, and these positions do not have leading zeros in the csv files, this
#function is used. Lubridate returns numeric values for each place, so no leading zeros will be present. Because the minute
#and second positions do have leading zeros in the csv, the format() function is used there. However, a string of NAs, 
#separated by the separator values in the paste statements, would appear if these commands were used on a whole column,
#so this function is intended to be used with apply() functions and returns NA if a data element is blank
date.to.string <- function(date.value){
     ifelse(!is.na(as.character(date.value)),
            paste0(
                 paste(month(date.value), day(date.value), year(date.value), sep = '/'), 
                 ' ', hour(date.value), ':', format(date.value, '%M:%S')),
            NA)
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
current.day <- format(Sys.Date() - 1, "%Y%m%d")
dest.file <- list.files(paste("C:\\Users", Sys.info()[["user"]], "Downloads", sep = "\\"),
                        pattern = paste0("^(result|encounter|outreachattempt)_", current.day), 
                        full.names = TRUE) %>%
     file.info

#Reads the result file into R using the nrc.df function and transmutes the columns to match the original formatting of
#the responses file. For most this just means changing the column names, but for a few columns some additional
#adjustments need to be made. The transmute function was used because it only keeps those values you select to modify;
#all other columns are removed.
result.df <- nrc.df("result_") %>%
     transmute(Address = person_address,
               City = person_city,
               CompleteDate = outreachattempt_completedate,
               DischargeDr = medicalvisit_dischargedr,
               DOB = person_dob,
               Gender = person_gender,
               #The new language field is all capital letters, while the original only capitalized the first letter.
               #This script separates the first and following letters, makes the second part lowercase, and recombines them
               Language = paste0(toupper(substr(person_language, 1, 1)), 
                                 tolower(substr(person_language, 2, length(person_language)))),
               Location = location_name,
               MaritalStatus = person_maritalstatus,
               MRN = medicalvisit_mrn,
               NRCEncounterID = medicalvisit_id,
               OutreachDate = outreachattempt_sendondate,
               #The outreach.type.conversion function can only apply to string at a time, not an entire column. So the
               #sapply function is used to loop through the entire outreachattempt_surveymethod column and apply each row
               #to the function
               OutreachType = sapply(.$outreachattempt_surveymethod, outreach.type.conversion),
               Passthru01 = passthru_01,
               #If the FIN starts with a dash, then it's for the Nurse Advice Line and doesn't represent an account. These
               #strings need to be reformatted, by combining their composite parts (discharge date and mrn) to to save 
               #space. If there is no dash, it is added as normal.
               Passthru02 = if_else(grepl('^-', medicalvisit_visitnum),
                                    FIN.formatted(medicalvisit_dischargedate, medicalvisit_mrn),
                                    as.character(medicalvisit_visitnum)),
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
               VisitDate = medicalvisit_dischargedate,
               VisitType = medicalvisit_visittype,
               Zip = person_zip)

#Reads the outreachattempt file into R using the nrc.df function and transmutes the columns to match the original formatting 
#of the encounters file. For most this just means changing the column names, but for a few columns some additional
#adjustments need to be made. The transmute function was used because it only keeps those values you select to modify; all
#other columns are removed. The as.POSIXct function is used because the summarize function further down requires that these
#values be in the datetime format. Because the original encounters file only showed the most recent outreach attempt and the 
#outreachattempt file shows all attempts, the table is grouped on its NRCEncounterID, which occurs only once per encounter,
#and the max value of the OutreachDate, CompleteDate, and OutreachType is obtained for each ID via the summarize function.
#na.rm is used so that the presence of NAs doesn't cause the the max function to just return an NA regardless of any dates
#present. This results in warnings for IDs where only NAs are present, but otherwise the function works as intended. 
#Finally, the mutate function is used to adjust the Outreach function to exclude the outreachattempt_id and equate the
#numeric survey method value with its string counterpart (which can only be done one value at a time, which is why the sapply
#loop function is applied over the OutreachType column) without removing all of the other columns, which is what happens with
#the transmute function. Mutate is also used to convert the CompleteDate and OutreachDate values into strings via the 
#date.to.string function. The sapply loop is needed in case the value is a NA, so the columns must be converted point-by-point
outcomes.df <- nrc.df("outreachattempt_") %>%
     transmute(NRCEncounterID = medicalvisit_id,
               CompleteDate = as.POSIXct(outreachattempt_completedate, format = "%m/%d/%Y %H:%M:%S"),
               #Formerly this field was just a TRUE/FALSE description of if the survey had ben completed or not. The TRUEs
               #in the original line up with only 'Survey Complete' in the current version, so all others are considered FALSE
               IsReturned = if_else(outreachattempt_currentstatusdescription == 'Survey Complete', 'TRUE', 'FALSE'),
               OutreachDate = as.POSIXct(outreachattempt_sendondate, format = "%m/%d/%Y %H:%M:%S"),
               #Only the most recent outreachattempt_surveymethod is needed, and the other datetime fields that contain
               #unique times for each outreach attempt are often NULL. Because of this and outreachattempt_id is sequential,
               #it is used to identify the most recent outreach attempt instead of a date field
               AllOutreachType = paste0( outreachattempt_id, "_", outreachattempt_surveymethod )) %>%
     group_by(NRCEncounterID) %>%
     summarize(OutreachDate = max(OutreachDate, na.rm = TRUE), CompleteDate = max(CompleteDate, na.rm = TRUE),
               IsReturned = max(IsReturned, na.rm = TRUE), OutreachType = max(AllOutreachType, na.rm = TRUE)) %>%
     mutate(OutreachType = sapply(OutreachType, outreach.type.conversion), 
            CompleteDate = sapply(CompleteDate, date.to.string),
            OutreachDate = sapply(OutreachDate, date.to.string))

#Reads the encounter file into R using the nrc.df function and transmutes the columns to match the original formatting 
#of the encounters file. For most this just means changing the column names, but for a few columns some additional
#adjustments need to be made. The transmute function was used because it only keeps those values you select to modify;
#all other columns are removed. Additionally, any row with a blank Financial Number (in the Passthru02 field) isn't 
#supposed to be in the data output, so it's removed from the report. The original encounters file contained outcomes 
#information, which is now stored in the outcomeattempts file. To obtain this information, the results of the transmuted
#encounter file are merged with the already transmuted outreach file on the NRCEncounterID field. The outreach file
#already contains only the maximum results for each field to match the contents of the original encounter file. The merger
#throws off the order of the fields by putting NRCEncounterID at the beginning and the outreach data at the end, which 
#doesn't match the original outline. The select statement is used to reorder these columns to match the original outline
encounter.df <- nrc.df("encounter_") %>%
     transmute(Address = person_address,
               City = person_city,
               DischargeDr = medicalvisit_dischargedr,
               DOB = person_dob,
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
               #If the FIN starts with a dash, then it's for the Nurse Advice Line and doesn't represent an account. These
               #strings need to be reformatted, by combining their composite parts (discharge date and mrn) to to save 
               #space. If there is no dash, it is added as normal.
               Passthru02 = if_else(grepl('^-', medicalvisit_visitnum),
                                    FIN.formatted(medicalvisit_dischargedate, medicalvisit_mrn),
                                    as.character(medicalvisit_visitnum)),
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
               VisitDate = medicalvisit_dischargedate,
               VisitType = medicalvisit_visittype,
               Zip = person_zip) %>%
     filter(!is.na(Passthru02)) %>%
     merge(outcomes.df, by = "NRCEncounterID") %>%
     select(Address, City, CompleteDate, DischargeDr:Gender, IsReturned, Language:MRN, NRCEncounterID,
            OutreachDate, OutreachType, Passthru01:Zip)

#Writes the resulting encounter and results data frames (outcomes isn't needed because it's merged with the encounter table)
#to new csv files in the Downloads folder
write.to.folder(result.df, "Responses_")
write.to.folder(encounter.df, "Encounters_")