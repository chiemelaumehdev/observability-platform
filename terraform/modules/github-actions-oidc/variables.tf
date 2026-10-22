variable "repositories" {
  description = "List of GitHub repositories allowed to assume an ECR-push role, each with the branches they can push from."
  type = list(object({
    repo     = string
    branches = list(string)
  }))
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the role is allowed to push to."
  type        = list(string)
}
