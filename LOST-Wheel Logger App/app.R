# Package names
packages <- c("shiny", "serial", "tidyverse", "ggplot2", "ggpubr", "dplyr", "data.table", "tibble", "stringr", "tidyr", "shinybusy", "shinythemes", "shinyjs")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
}

library(shiny)
library(serial)
library(tidyverse)
library(ggplot2)
library(ggpubr)
library(dplyr)
library(data.table)
library(tibble)
library(stringr)
library(tidyr)
library(zoo)
library(shinybusy)
library(shinythemes)
library(shinyjs)


ui<- fluidPage(useShinyjs(),theme = shinytheme("superhero"), tags$style(type="text/css", ".shiny-output-error { visibility: hidden; }"),
                  
                  titlePanel("LOST-Wheel Logger"),
                  
                  sidebarLayout(
                      sidebarPanel(
                          textInput("name", "Enter a unique name", "ex: mouse1"),
                          selectInput("port","Select Port",choices = c(listPorts())),
                          numericInput("time","Duration to collect data (enter in hours)",min = 0,max=26,step = 0.01,value = 0.004),
                          actionButton("submit","Start",  style="color: #fff; background-color: #337ab7; border-color: #2e6da4"),
                          downloadButton("uidownloadData", "Download Raw Data")
                      ),
                      
                      # Show a plot of the generated distribution
                      mainPanel(
                          uiOutput("error"),
                          uiOutput("report_ui"),
                          uiOutput("plot1_ui"),
                          uiOutput("plot2_ui")
                      )
                  )
)


# Define server logic required to draw a histogram
server <- (function(input, output, session) {
    if (!interactive()) {
        session$onSessionEnded(function() {
            stopApp()
            q("no")
        })
    }
    code <- eventReactive(input$submit,{
        disable("submit")
        starttime <- as.character(Sys.time())
        con<-serialConnection(name = input$name, port = input$port, 
                              mode = "9600,n,8,1",
                              buffering = "full",
                              newline = "0",
                              eof = "",
                              translation = "auto",
                              handshake = "none",
                              buffersize = "100000000")
        
        timecollecth <- input$time
        lengthofcollect <- timecollecth*60*60 #turning hours into seconds
        
        wheelmatrix <- matrix(NA,lengthofcollect,2) #setting up matrix to collect data
        
        test <- tryCatch({
            close(con) #turn off wheel
            Sys.sleep(0.5) #hold
            open(con) #turn on wheel
            Sys.sleep(3.0) #startuptime is 3 seconds so hold some more
            
            TRUE
        },error=function(e){
            FALSE
        })
        
        if(test == FALSE){
            data <- FALSE
        }else{
            show_modal_spinner(text = HTML("<br>collecting wheel data
                              <br>DO NOT CLOSE THIS WINDOW"), spin = sample(c("breeding-rhombus", "flower", "fulfilling-square", "atom"),1), color = "#e89a1c")
            
            for (i in 1:lengthofcollect) { #keep collecting until lengthofcollect is reached
                
                
                lastread <- read.serialConnection(con) #read the serial output
                wheelmatrix[i,2]<-lastread #put the distance into the matrix
                Sys.sleep(1) #wait a second until the wheel sends next value
                print(paste("wheel collection ongoing - min remaining:", round(((lengthofcollect-i)/60),1)))
            }
            
            remove_modal_spinner()
            endtime <- as.character(Sys.time())
            close(con) #turn off wheel
            
            splitstringmatrix <- matrix(NA,lengthofcollect,3)
            wheelmatrix[,2] -> splitstringmatrix[,1]
            splitstringmatrix[,2:3]<-str_split_fixed(splitstringmatrix[,1], " , ", 2)
            
            wheel_mat_numeric <- matrix(NA, lengthofcollect,4)
            
            colnames(wheel_mat_numeric) <-c("time","distance","slope", "rolling velocity avg")
            wheel_mat_numeric[,1] <- as.numeric(splitstringmatrix[,2]) #turn strings into numeric (factor)
            wheel_mat_numeric[,2] <- as.numeric(splitstringmatrix[,3])
            wheeltibble <- as_tibble(wheel_mat_numeric) #turn matrix into dataframe
            
            dtplot <- wheeltibble %>% 
                rename(time_sec = time, distance_m = distance) %>% 
                ggplot(aes(time_sec, distance_m, group = 1)) +
                ggtitle(paste(input$name, "distance")) +
                labs(y = "distance (m)", x = "time (s)") +
                geom_point() +
                geom_line() +
                theme(text = element_text(size=20))
            for (i in 1:lengthofcollect){
                wheeltibble[i:(lengthofcollect-1),3]<- ((wheeltibble[i+1,2]-wheeltibble[i,2])/(wheeltibble[i+1,1]-wheeltibble[i,1]))
                
            }
            
            vtplot <- wheeltibble %>% 
                rename(time_sec = time, velocity_m_per_s = slope) %>% 
                ggplot(aes(time_sec, velocity_m_per_s, group = 1)) +
                ggtitle(paste(input$name, "velocity")) +
                ylim(0,4) + 
                theme(text = element_text(size=20)) +
                labs(y = "velocity (m/s)", x = "time (s)") +
                geom_point() +
                geom_line()+
                geom_line(aes(y=rollmean(wheeltibble[,3],5,na.pad=TRUE)), color = "orange",size = 1) 
            
            maxspeed <- max(wheeltibble[,3],na.rm = TRUE)
            
            wheeltibble[,4]<-rollmean(wheeltibble[,3],4, na.pad=TRUE) #calculate a rolling mean to clean up any noise
            cleanwheeltibble<-na.omit(wheeltibble) ##get rid of any NAs
            
            for (i in 1:lengthofcollect){  #loop to set threshold that changes very slow turns into 0 b/c likely not running 
                
                ifelse(cleanwheeltibble[i,3]>0.2,cleanwheeltibble[i,5]<- cleanwheeltibble[i,3],cleanwheeltibble[i,5] <- 0) 
                
            }
            names(cleanwheeltibble)[5]<-"clean_velocity"#rename new column
            
            finaltibble <- cleanwheeltibble %>%
                mutate(t_lead = lead(time)-time) 
            
            timestopped <- finaltibble %>%
                filter(clean_velocity == 0) %>%
                na.omit() %>%
                summarize(sum_time = sum(t_lead))
            
            timeran <- (last(finaltibble[,1]) - timestopped)
            finaldistance <- last(finaltibble[,2]-0)
            
            FinalReport<-tibble(
                                "maximum speed (meters/s):" = round(maxspeed,2), 
                                "time spent running (s):" = round(timeran[1,1],2)-2.51,
                                "final distance (m):"= finaldistance[1,1],
                                "start time" = starttime,
                                "end time" = endtime)
           
            data <- list(FinalReport,dtplot,vtplot,cleanwheeltibble)
        }
        
        data
        
    })
    
    
    
    output$plot1 <- renderPlot({
        code <- code()
        code[[2]]
    })
    
    output$plot2 <- renderPlot({
        code <- code()
        code[[3]]
    })
    
    output$report <- renderTable({
        code <- code()
        data <- as.data.frame(code[[1]]) 
        colnames(data) <- c("Maximum Speed (m/s)", "Time Spent Running (s)", "Final Distance (m)", "Start Time", "End Time")
        data
    })
    
    output$plot1_ui <- renderUI({
        code <- code()
        if(class(code) == "list"){
            plotOutput("plot1")
        }
        
    })
    
    output$plot2_ui <- renderUI({
        code <- code()
        if(class(code) == "list"){
            plotOutput("plot2")
        }
        
    })
    
    output$report_ui <- renderUI({
        code <- code()
        if(class(code) == "list"){
            tableOutput("report")
        }
        
    })
    
    output$error <- renderUI({
        code <- code()
        if(class(code) != "list"){
            
            h4(tags$b("No device found at the selected port!"))
        }else{
            tags$br()
        }
        
    })
    
    output$uidownloadData <- downloadHandler(filename = "data.csv",content = function(file){
        code <- code()
        data <- as.data.frame(code[[4]]) 
        write.csv(data,file)
    })
    
})

# Run the application 
shinyApp(ui = ui, server = server)
