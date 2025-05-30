import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { DeploymentMode } from "../../src";
import { config as dotenvConfig } from "dotenv";
import { mode } from "../config/config";
import { getS3Config } from "../s3Config/buildConfig";

dotenvConfig();

const getBucketName = () => {
  switch (mode) {
    case DeploymentMode.LOCAL:
      return "socketpoc";
    case DeploymentMode.DEV:
      return "socketpoc";
    case DeploymentMode.STAGE:
      return "socket-stage";
    case DeploymentMode.PROD:
      return "socket-prod";
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};

const getFileName = () => {
  switch (mode) {
    case DeploymentMode.LOCAL:
      return "pocConfig.json";
    case DeploymentMode.DEV:
      return "devConfig.json";
    case DeploymentMode.STAGE:
      return "stageConfig.json";
    case DeploymentMode.PROD:
      return "prodConfig.json";
    default:
      throw new Error(`Invalid deployment mode: ${mode}`);
  }
};
// Initialize S3 client
const s3Client = new S3Client({ region: "us-east-1" }); // Replace with your preferred region

// Function to upload to S3
async function uploadToS3() {
  const fileName = getFileName();
  const bucketName = getBucketName();
  const data = getS3Config();
  console.log(JSON.stringify(data, null, 2));
  const params = {
    Bucket: bucketName,
    Key: fileName,
    Body: JSON.stringify(data, null, 2),
    ContentType: "application/json",
  };

  try {
    const command = new PutObjectCommand(params);
    await s3Client.send(command);
    console.log(`Successfully uploaded ${fileName} to S3 bucket ${bucketName}`);
  } catch (error) {
    console.error(`Error uploading ${fileName} to S3:`, error);
  }
}

uploadToS3();
