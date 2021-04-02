Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash

sudo yum update -y

sleep 2
### Installing
sudo yum install golang -y
/bin/go version
sudo yum update -y

sudo mkdir -p /opt/Goapp

cat << EOF > /opt/Goapp/host-app.go
package main
import (
  "fmt"
  "net/http"
  "os"
)
func handler(w http.ResponseWriter, r *http.Request) {
  h, _ := os.Hostname()
  fmt.Fprintf(w, "Hi there, I'm served from %s!", h)
}
func main() {
  http.HandleFunc("/", handler)
  http.ListenAndServe(":8484", nil)
}
EOF

sudo chown root:ec2-user /opt/Goapp -R
sudo chmod +x /opt/Goapp -R
sudo /bin/go run /opt/Goapp/host-app.go &
