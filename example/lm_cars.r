require(stats)
linearMod <- lm(dist ~ speed, data=cars)  # build linear regression model on full data
make_prediction <- function(x) {

  new_df <- data.frame(speed = x)
  prediction<- predict(linearMod, new_df)


  return(prediction)

}
