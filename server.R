###load 'shiny' package
if (!require(shiny)) {
  install.packages("shiny")
}
##load 'dplyr' package
if (!require(dplyr)) {
  install.packages("dplyr")
  library(dplyr)
}  else  {
  library(dplyr)
}
##load 'zeitzeiger' package
if (!require(zeitzeiger)) {
  install.packages("dplyr")
  library(dplyr)
  if (!require(devtools)) {
    install.packages("devtools")
    library(devtools)
  } else {
    library(devtools)
  }
  devtools::install_github('hugheylab/zeitzeiger')
}  else  {
  library(dplyr)
}

### By default, the file size limit is 5MB. It can be changed by
### setting this option. Here we'll raise limit to 100MB.
options(shiny.maxRequestSize = 100*1024^2, stringsAsFactors = FALSE)

### load the data
expD = readRDS("SkinPhaserExp.rds")
phaD = readRDS("SkinPhaserPha.rds")
exampleD = readRDS("SkinPhaserFormat.rds")

###set a flag for 'Run' button
runflag <- 0
###uploading file
shinyServer(function(input, output) {
  ## show the example data
  output$example <- renderTable({
    return( head(exampleD) )
  })
  ## show the input datafile
  output$contents <- renderTable({
    ## input$file1 will be NULL initially. After the user selects and uploads a file, 
    ## it will be a data frame with 'name', 'size', 'type', and 'datapath' columns.
    ## The 'datapath' column will contain the local filenames where the data can be found.
    inFile <- input$file1
    if (is.null(inFile)) {
      return(NULL)
    }
    testD <-  read.csv(inFile$datapath)
    if ( ncol(testD) < 2 ) {
      testD <- read.delim(inFile$datapath)
    } 
    return( head(testD) )
  })
  ## show the necessay value during running shiny function
#   output$teptext <- renderText({
#    tepF <- input$outraw
#    return(class(tepF))
#   })
  ## predict the sample phase
  datasetInput <- reactive({
    ## Change when the "update" button is pressed
    if ( input$update > runflag) {
      isolate({
        withProgress({
          setProgress(message = "Processing corpus...")
          
          inFile <- input$file1
          if (is.null(inFile)) {
            return(NULL)
          }
          testD <-  read.csv(inFile$datapath)
          if ( ncol(testD) < 2 ) {
            testD <- read.delim(inFile$datapath)
          } 
          colnames(testD)[1] = "geneSym"
          ##change the non-offical name to the offical name in the test data
          testD$geneSym = gsub("C1orf51", "CIART", testD$geneSym, fixed = TRUE)
          testD$geneSym = gsub("PBEF1", "NAMPT", testD$geneSym, fixed = TRUE)
          rownames(testD) = testD$geneSym
          
          ##get the overlapped gene list
          markerGenes = base::intersect(expD$geneSym, testD$geneSym)
          
          ##get the internal control gene list
          normGenes = unlist( strsplit(gsub("\\s+", "", input$normGenes, perl = TRUE), ",", fixed = TRUE) )
          
          ##if there are more than five samples and there are internal control genes, run the analysis
          if ( (length(normGenes) > 0) & ( ncol(testD) >= 6) )  {
            ##assign the quantile percentile according to the number of samples
            if (ncol(testD) <= 50) {
              min_prob = 0.1
            } else if ( (ncol(testD) > 50) & (ncol(testD) <= 200) ) {
              min_prob = 0.05
            } else {
              min_prob = 0.025
            }
            
            ##do the normalization in each column
            normExp =  apply(testD[normGenes,-1], 2, mean)
            normD = t( apply( testD[,-1], 1, function(z, zn = normExp) {return(z/zn)} ) )
            rownames(normD) = testD$geneSym
            
            ##do the row or peak phase normalization (reduce extreme value then norm each row)
            normD <- apply(normD, 1, function(z) {
              zq = quantile(z, probs = c(min_prob, (1 - min_prob) ), na.rm = TRUE)
              ##suppose no missing value in the expression profile
              z[z < zq[1]] = zq[1]
              z[z > zq[2]] = zq[2]
              return(z/max(z, na.rm = TRUE))
              } )
            
            ##need to transpose the matrix, because apply re-structure the matrix
            testD = as.data.frame( t(normD) ) %>% 
                    dplyr::mutate(geneSym = testD$geneSym) %>% 
                    dplyr::select(geneSym, colnames(testD)[-1] ) 
            rownames(testD) = testD$geneSym
            testD = testD[markerGenes,]
            
            ##get the training data
            trainD = expD %>% dplyr::select(geneSym, phaD$sampleID)
            rownames(trainD) = trainD$geneSym
            trainD = trainD[markerGenes,]
            
            ##get the SPC
            xTrain = t(trainD[,-1])
            colnames(xTrain) = trainD$geneSym
            fitResult = zeitzeigerFit(xTrain, phaD$timeTrain)
            spcResult = zeitzeigerSpc(fitResult$xFitMean, fitResult$xFitResid, nTime=nrow(xTrain), sumabsv = 2)
            
            ##predict the phase for the test samples
            xTest = t(testD[,-1])
            colnames(xTest) = testD$geneSym
            predResult = zeitzeigerPredict(xTrain, phaD$timeTrain, xTest, spcResult, nSpc=2)
            
            ##prepare the ouput table
            dfTest = data.frame(sampleID = rownames(xTest), phase = predResult$timePred*2*pi)
          }  else  {
            dfTest = NULL
          }
        })
      })
      runflag <- input$update
      return(dfTest)
    }  else  {
      return(NULL)
    }
  })
  ## show the prediction result
  output$tabout <- renderTable({
    taboutD <- datasetInput()
    head(taboutD)
  })
  ## downloading file
  output$downloadData <- downloadHandler(
    filename = function() { 
      if (input$fstyle == "txt") {
        paste("SkinPhaser", '.txt', sep='') 
      }  else  {
        paste("SkinPhaser", '.csv', sep='') 
      }
    },
    content = function(file) {
      if (input$fstyle == "txt") {
        write.table(datasetInput(), file, quote = FALSE, sep="\t", row.names=FALSE)
      }  else  {
        write.csv(datasetInput(), file, row.names=FALSE)
      }
    }
  )
})
