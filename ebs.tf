
resource "aws_ebs_volume" "rust_persistent" {
  availability_zone = local.availability_zone
  iops              = 1200
  size              = 50
  type              = "io1"
  tags = {
    Name = "${var.server_name}-persistent-volume"
  }
}

resource "aws_volume_attachment" "rust_ec2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.rust_persistent.id
  instance_id = aws_instance.rust.id
}
