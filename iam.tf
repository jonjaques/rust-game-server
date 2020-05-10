data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = "assumerole"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "ec2" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "cloudwatch:PutMetricData",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ssm:DescribeParameter",
      "ssm:GetParameter"
    ]

    effect = "Allow"

    resources = ["*"]
  }
}


resource "aws_iam_role" "ec2" {
  name               = "describe_volumes_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "ec2_describe_volumes_profile" {
  name = "ec2_describe_volumes_profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role_policy" "ec2_describe_volumes_policy" {
  name   = "ec2_describe_volumes_policy"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2.json
}
