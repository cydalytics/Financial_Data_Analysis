
### Data Scraping

# Import Libraries
require(XML)
require(RSelenium)
require(data.table)

# Open the Remote Browser
remDr = remoteDriver(remoteServerAddr = "localhost", browserName = "chrome")
remDr$open()
remDr$setTimeout(type = "implicit", milliseconds = 50000)
remDr$setTimeout(type = "page load", milliseconds = 50000)

# HSI List
remDr$navigate("http://www.etnet.com.hk/www/eng/stocks/indexes_detail.php?subtype=HSI")
tables = getNodeSet(htmlParse(remDr$getPageSource()[[1]]), "//table")
df = readHTMLTable(tables[[3]],Encoding("UTF-8"))
hsi_list = paste(substr(as.character(df$V1[-1]), 2, 5), "HK", sep = ".")

# Download CSV Files
for (hsi_idx in c("^HSI", hsi_list)){
  website = paste("https://finance.yahoo.com/quote/", hsi_idx, "/history?period1=536342400&period2=1569772800&interval=1d&filter=history&frequency=1d", sep = "")
  remDr$navigate(website)
  remDr$findElement(using = "xpath", '//*[@id="Col1-1-HistoricalDataTable-Proxy"]/section/div[1]/div[2]/span[2]/a/span')$clickElement()
}

# Merging CSV Files
file_list = list.files(pattern = ".csv")
raw_df = NULL
for (file in file_list){
  df = read.csv(file, stringsAsFactors = F)
  df$Index = substr(file, 1, nchar(file) - 4)
  raw_df = rbind(raw_df, df)
}
write.csv(raw_df, "raw_df.csv", row.names = F)

### Data Preprocessing

# Remove Missing Data
master_df = raw_df[!raw_df$Close == "null",]

# Convert Data Type
master_df$Date = as.Date(master_df$Date)
for (col_idx in c(2:7))
  master_df[, col_idx] = as.numeric(master_df[, col_idx])

# Align the Start Date
master_dt = setDT(master_df)
start_date_df = master_dt[, .(Start_Date = min(Date)), by = Index]
master_dt = master_dt[master_dt$Date >= "2010-11-01",]

# Align the Trading Date
count_date_df = master_dt[, .N, by = Date]
date_miss_df = subset(count_date_df, N != 47)
master_dt = master_dt[!master_dt$Date %in% date_miss_df$Date,]

# Stock Dataframe
stock_df = data.frame(matrix(master_dt$Close, ncol = 47))
colnames(stock_df) = master_dt$Index[!duplicated(master_dt$Index)]
stock_df = cbind(Date = master_dt$Date[!duplicated(master_dt$Date)], stock_df)
write.csv(stock_df, "stock_df.csv", row.names = F)
