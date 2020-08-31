#!/usr/bin/bash

cert_path=/home/student/DO380/labs/certificates-review

lab certificates-review start

sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify create configmap review-bundle --from-file ca-bundle.crt=${cert_path}/review-combined.pem -n openshift-config
sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify patch proxy/cluster --type=merge -p '{"spec":{"trustedCA":{"name":"review-bundle"}}}'

sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify create secret tls review-tls --cert ${cert_path}/review-combined.pem --key ${cert_path}/review-key.pem -n openshift-ingress
sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "review-tls"}}}' -n openshift-ingress-operator

# Not creating the secret simulates a problem that a student created.
# In this scenario, the admin and kubeadmin users should be locked out.
# Running 'oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify' should still work, but students do not have this information.
# Although grading will fail, the finish function *should* still clean up appropriately.
#sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify create secret tls review-tls --cert ${cert_path}/review-combined.pem --key ${cert_path}/review-key.pem -n openshift-config
sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify patch apiserver cluster --type=merge -p '{"spec":{"servingCerts": {"namedCertificates": [{"names": ["api.ocp4.example.com"], "servingCertificate": {"name": "review-tls"}}]}}}'

echo "Sleeping for 2 minutes"
sleep 120
echo "Waiting for 'co/kube-apiserver' to stop progressing"

API_PROGRESSING="true"
until [ "${API_PROGRESSING,,}" == "false" ]
do
  API_PROGRESSING=$(sudo oc --kubeconfig /root/.kubeconfig --insecure-skip-tls-verify get co/kube-apiserver -o jsonpath='{range .status.conditions[?(@.type=="Progressing")]}{.status}{end}')
  if [ "${API_PROGRESSING,,}" == "false" ]
  then
    break
  else
    sleep 10
  fi
done

# I think many of these checks will succeed.
# It doesn't really matter though.
lab certificates-review grade

# The lab_finish function should revery apiserver/cluster to use the default certiifcate.
# This caused 'co/kube-apiserver' to start progressing.
# The lab_finish function should wait until 'co/kube-apiserver' starts progressing.
# Hopefully this does successfully revert the cluster.
lab certificates-review finish
