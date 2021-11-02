
// Make sure that the Default VPC is available
// This code block will not create default VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}