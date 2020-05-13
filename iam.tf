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
      "logs:PutLogEvents"
    ]

    effect = "Allow"

    resources = ["*"]
  }
}


resource "aws_iam_role" "ec2" {
  name_prefix        = "rust"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "ec2_describe_volumes_profile" {
  name_prefix = "rust"
  role        = aws_iam_role.ec2.name
}

resource "aws_iam_role_policy" "ec2_describe_volumes_policy" {
  name_prefix = "rust"
  role        = aws_iam_role.ec2.id
  policy      = data.aws_iam_policy_document.ec2.json
}
