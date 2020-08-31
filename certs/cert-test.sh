#!/usr/bin/bash

cert_path=/home/student/DO380/labs/certificates-review

lab certificates-review start

oc create configmap review-bundle --from-file ca-bundle.crt=${cert_path}/review-combined.pem -n openshift-config
oc patch proxy/cluster --type=merge -p '{"spec":{"trustedCA":{"name":"review-bundle"}}}'

oc create secret tls review-tls --cert ${cert_path}/review-combined.pem --key ${cert_path}/review-key.pem -n openshift-ingress
oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "review-tls"}}}' -n openshift-ingress-operator

oc create secret tls review-tls --cert ${cert_path}/review-combined.pem --key ${cert_path}/review-key.pem -n openshift-config
oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts": {"namedCertificates": [{"names": ["api.ocp4.example.com"], "servingCertificate": {"name": "review-tls"}}]}}}'

echo "Sleeping for 2 minutes"
sleep 120
echo "Waiting for 'co/kube-apiserver' to stop progressing"

local API_PROGRESSING="true"
until [ "${API_PROGRESSING,,}" == "false" ]
do
  API_PROGRESSING=$(oc ${SYSTEM_ADMIN} get co/kube-apiserver -o jsonpath='{range .status.conditions[?(@.type=="Progressing")]}{.status}{end}')
  if [ "${API_PROGRESSING,,}" == "false" ]
  then
    break
  else
    sleep 10
  fi
done

# All grading should pass, but this is not necessary for this test.
lab certificates-review grade

# The lab_finish function should revery apiserver/cluster to use the default certiifcate.
# This caused 'co/kube-apiserver' to start progressing.
# The lab_finish function should wait until 'co/kube-apiserver' starts progressing.
lab certificates-review finish

# The ocp4_login_as_admin function should fail with a message indicating that 'co/kube-apiserver' is progressing.
lab pools-adding-workers start
