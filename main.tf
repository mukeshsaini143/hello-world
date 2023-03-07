# Define the provider
provider "aws" {
  region = "us-east-1"
}

# Define the variables
variable "app_name" {
  default = "my-node-app"
}

variable "github_repo_url" {
  default = "https://github.com/your-username/my-node-app.git"
}

variable "github_branch" {
  default = "main"
}

# Define the S3 bucket
resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "${var.app_name}-artifact-bucket"
  acl    = "private"
}

# Define the IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.app_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# Define the IAM policy for CodePipeline
resource "aws_iam_policy" "codepipeline_policy" {
  name        = "${var.app_name}-codepipeline-policy"
  policy      = file("${path.module}/policies/codepipeline_policy.json")
  description = "IAM policy for CodePipeline"
}

# Attach the IAM policy to the CodePipeline role
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  policy_arn = aws_iam_policy.codepipeline_policy.arn
  role       = aws_iam_role.codepipeline_role.name
}

# Define the CodePipeline pipeline
resource "aws_codepipeline" "my_node_app_pipeline" {
  name = "${var.app_name}-pipeline"

  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  role_arn = aws_iam_role.codepipeline_role.arn

  stage {
    name = "Source"

    action {
      name            = "Source"
      category        = "Source"
      owner           = "ThirdParty"
      provider        = "GitHub"
      version         = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "your-username"
        Repo       = "my-node-app"
        Branch     = "main"
        OAuthToken = var.github_access_token
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
      input_artifacts = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.my_node_app_build_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["build_output"]
      configuration   = file("${path.module}/templates/cloudformation_deploy.json")
    }
  }
}

# Define the CodeBuild project
resource "aws_codebuild_project" "my_node_app_build_project" {
  name = "${var.app_name}-build-project"

  service_role = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL
