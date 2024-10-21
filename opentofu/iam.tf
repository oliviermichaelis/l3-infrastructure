resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
  tags             = local.tags

  depends_on = [module.eu-central-1, module.eu-west-3]
}

