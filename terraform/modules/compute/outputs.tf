output "public_ip" {
  value = aws_instance.app.public_ip
}
output "public_dns" {
  value = aws_instance.app.public_dns
}
output "sg_id" {
  value = aws_security_group.ec2_sg.id
}
