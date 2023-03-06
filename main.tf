# Define the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Define the S3 bucket to store the Lambda function code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "my-hello-world-lambda-bucket"
  acl    = "private"
}

# Create a CodeCommit repository to store the application code
resource "aws_codecommit_repository" "hello_world" {
  repository_name = "hello-world"
}

# Define the IAM role for the CodeBuild project
resource "aws_iam_role" "codebuild_role" {
  name = "my-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# Attach an IAM policy to the CodeBuild role to grant access to the S3 bucket
resource "aws_iam_role_policy_attachment" "codebuild_s3_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.codebuild_role.name
}

# Define the CodeBuild project to build the Node.js application and package it for deployment to Lambda
resource "aws_codebuild_project" "hello_world_build" {
  name       = "hello-world-build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "zip"
    name = "lambda-deployment-package"

    location = aws_s3_bucket.lambda_bucket.bucket
    path     = "hello-world/lambda-deployment-package.zip"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type = "CODECOMMIT"

    location = aws_codecommit_repository.hello_world.repository_clone_url_http
    buildspec = "hello-world/buildspec.yml"
  }

  cache {
    type = "S3"
    location = "my-hello-world-build-cache"
  }
}

# Define the CodePipeline to deploy the Lambda function and create the API Gateway endpoint
resource "aws_codepipeline" "hello_world_deploy" {
  name = "hello-world-deploy"

  artifact_store {
    location = aws_s3_bucket.lambda_bucket.bucket
    type     = "S3"
  }

  role_arn = aws_iam_role.codepipeline_role.arn

  stage {
    name = "Source"

    action {
      name            = "Source"
      category        = "Source"
      owner           = "AWS"
      provider        = "CodeCommit"
      version         = "1"
      output_artifacts = ["hello_world_app"]

      configuration = {
        RepositoryName = aws_codecommit_repository.hello_world.repository_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["hello_world_app"]
      output_artifacts = ["lambda_deployment_package"]

      configuration = {
        ProjectName = aws_codebuild_project.hello_world_build.name
      }
    }
  }
