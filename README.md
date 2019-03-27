# aws-lambda-r-runtime
Copy from https://github.com/bakdata/aws-lambda-r-runtime
[![Build Status](https://travis-ci.com/bakdata/aws-lambda-r-runtime.svg?branch=master)](https://travis-ci.com/bakdata/aws-lambda-r-runtime)

This package makes it easy to run AWS Lambda Functions written in R.

## Build custom R lambda layer
In order to install additional R packages than on the default layer, you can create a lambda layer yourself containing the libraries you want.
You must use the the compiled package files.
The easiest way is to install the package with `install.packages()` and copy the resulting folder in `$R_LIBS`.
Using only the package sources does not suffice.
The file structure must be `R/library/<MY_LIBRARY>`.
See `build_recommended.sh` for an example.
If your package requires system libraries, place them in `R/lib/`.

### STEP 1. Create AWS EC2 instance
Start an EC2 instance which uses the [Lambda AMI](https://console.aws.amazon.com/ec2/v2/home#Images:visibility=public-images;search=amzn-ami-hvm-2017.03.1.20170812-x86_64-gp2).

Or command line (then you need your Keypair already in place (step 2)).
```bash
aws ec2 run-instances --image-id ami-657bd20a --count 1 --instance-type t2.medium --key-name <MyKeyPair>
```

### STEP 2. Create and load key MyKeyPair
Step 1 link gives you step by step instructions and asks you to create key pair if you don't have one you want to use already.

### STEP 3. Connect to instance
You can copy this line of code from the AWS console by clicking your instance and connect.
```bash
ssh -i "mykey-ec2.pem" ec2-user@XXXXXX.us-west-2.compute.amazonaws.com
```

### STEP 4. Run (or copy, modify and run) build_r.sh script
Now run the `build_r.sh`  script.
You must pass the R version as a parameter to the script, e.g., `3.5.1`.
The script produces a zip containing a functional R installation in `/opt/R/`, e.g., `/opt/R/R-3.5.1.zip`.
Use this R distribution in the following.

### STEP 5. Create S3 bucket
Eg. [AWS quickstart guides](https://docs.aws.amazon.com/quickstarts/latest/s3backup/step-1-create-bucket.html)

### STEP 6. Save R zip to S3 for further use
Create a new user with AWS S3 permission and load secrets. Configure s3 keys on EC2.

```bash
aws configure set aws_access_key_id XXXXXXX
aws configure set aws_secret_access_key XXXXX
```
An then copy using command line (replace $VERSION with your version).
```bash
aws s3 cp /opt/R/R-$VERSION.zip \
  s3://bucket_name/layers/R-3.5.1.zip
```

### STEP 7. Build lambda layer (finally!)
With a compiled R distribution, you can build the runtime layer.
See the
`#remove some libraries to save space
recommended `
and modify to save space, since Lambda layer cannot exceed 50Mt.

If you plan to publish the runtime, you need to have a recent version of aws cli (>=1.16).
Copy the R distribution to the repository containing necessary scripts (`build_runtime.sh, runtime.R`) and run the `build_runtime_and_publish.sh` script.
This creates a lambda layer named `r-runtime` in your AWS account. You can see the result in [console](https://eu-central-1.console.aws.amazon.com/lambda/home?region=eu-central-1#/layer).


## Build lambda function with R
You need a function you want to work in the Lambda. Eg. return value for a trained model.

### STEP 1. Create R script

Create a script that has function in it. Eg. example folder `lm_cars.r` or
```R
require(stats)
linearMod <- lm(dist ~ speed, data=cars)  # build linear regression model on full data

make_prediction <- function(x) {

  new_df <- data.frame(speed = x)
  prediction<- predict(linearMod, new_df)
  return(prediction)

}

```

### STEP 2. Create Lambda
To run the example, we need to create a IAM role executing our lambda.
This role should have the following properties:
- Trusted entity – Lambda.
- Permissions – AWSLambdaAllpermissions.
Copy you role eg. `arn:aws:iam::XXXXXXXX:role/r-runtime` and paste to the script.

Furthermore you need a current version of the AWS CLI.

Then create a lambda function which uses the R runtime layer with `create_lambda.sh` or example:
```bash
#cd example/
chmod 755 lm_cars.r #which script you want to put in the Lambda
zip function.zip script.r #zip the function
aws lambda create-function --function-name r-example \ #give the Lambda function name
    --zip-file fileb://function.zip --handler lm_cars.make_prediction \ #tell which script and function
    --runtime provided --timeout 60 \
    --layers arn:aws:lambda:eu-central-1:131329294410:layer:r-runtime-3_5_1:1 \ #basic layer
      #arn:aws:lambda:eu-central-1:XXXXXXX:layer:r-runtime:1 \ #own layer with some other packages
    --role arn:aws:iam::XXXXXXXX:role/r-runtime --region eu-central-1 #paste your role info here
```
Note, using eg. 3-4 layers requires too much so keep it simple!

### STEP 3. Test Lambda
Either in [console](https://eu-central-1.console.aws.amazon.com/lambda/home?region=eu-central-1#/functions/r-ruimtehol3?tab=graph) setting a test case manually or with command line. Setting the test case, you can see the possible errors on console.
Function returns output of the model. The lambda function returns whatever is returned by the R function as a JSON object with `result` as a root element.

Invoke the function:
```bash
aws lambda invoke --function-name r-example \
    --payload '{"x":4}' --region eu-central-1 response.txt
cat response.txt ##see the response
```

The expected result should look similar to this:
```json
{
  "result": -1.8495
}
```

## Provided layers

Layers are only accessible in the AWS region they were published. See provided layer from https://github.com/bakdata/aws-lambda-r-runtime .

## Limitations

AWS Lambda is limited to running with 3GB RAM and must finish within 15 minutes.
It is therefore not feasible to execute long running R scripts with this runtime.
Furthermore, only the `/tmp/` directory is writeable on AWS Lambda.
This must be considered when writing to the local disk.
