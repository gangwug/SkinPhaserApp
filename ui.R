library(shiny)
##uploading file
shinyUI(fluidPage(
  titlePanel(h2("Welcome to SkinPhaser") ),
  sidebarLayout(
    
    sidebarPanel(
      fluidRow(
        column(6,
               fileInput('file1', label=h5('Choose data file'),
                         accept=c('text/csv', 
                                  'text/comma-separated-values,text/plain', '.csv')) ),
        column(6,
               radioButtons('fstyle', label=h5('File style'),
                            choices=c("csv"='csv', "txt"='txt'),
                            selected='csv', inline=FALSE) )
      ),
     fluidRow(
       column(12,
              radioButtons('markerGenesReminder', label=h5('How many marker genes were measured in epidermal samples?'),
                           choices=c("all 12 marker genes"='all', 
                                     "7 marker genes (ARNTL, NR1D1, CIART, PER1/2/3, DBP) or more"='partial'),
                           selected='all', inline=FALSE) )
      ),
     fluidRow(
       column(12,
              textInput("normGenes", label=h5("Internal control genes used for normalization"), value="GPKOW, BMS1, ANKFY1") )
     ),
     br(),
     br(),
     fluidRow(
       column(3,
              actionButton("update", label=h5("Run")) ),
       column(3,
              downloadButton('downloadData', label='Download' ) )
     )
    ),
    
    mainPanel(
      helpText(h4('Starting point: File format') ),
      helpText(h5('The input file contains expression values of measured circadian marker genes and internal control genes from each test human epidermal sample. At least 6 test samples were required. The file format should be like below:')),
      tableOutput('example'),
      helpText(h4('Step1: Upload') ),
      helpText(h5('Please take a look at the input file selected on the left:') ),
      tableOutput('contents'),
      ##the temporaly output value for checking the value during running shiny app
      #textOutput('teptext'),
      br(),
      helpText(h4('Step2: Run') ),
      helpText(h5('If the input file is shown as expected, please set parameters on the left and click Run button.') ),
      br(),
      helpText(h4('Step3: Download') ),
      helpText(h5('You could download the output results by clicking Download button on the left if you see the first six samples shown below.'),
      helpText(h5('The predicted circadian phase is between 0 and 2pi, with 0 indicating ARNTL phase.') ),
      tableOutput('tabout'))
    )
  )
))
