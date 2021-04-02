#### App server output ####
output "app_server_ip" {
  value = aws_instance.appserver[*].private_ip
}

#### Webserver output ####
output "web_server_dns" {
  value = aws_instance.webserver.public_dns
}
