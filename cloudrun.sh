#!/bin/bash

IMG_URL="europe-west1-docker.pkg.dev/or2-msq-epm-plx1-t1iylu/fast-api-stream-docker/streaming-bq@sha256:1b8b8c3f651ca0036ec10d8b1ede6b47d405ab4ca20f508a9ef1d417107d1d60"
WISH_TO_CONTINUE="Do you wish to continue? (y/N): "

WELCOME_TEXT="Please input the following information to set up your streaming server. For more
information about the configuration, input '?'. To use the recommended setting
or your current setting, leave blank."

SERVICE_PREFIX_HELP="  Provide a name for the Cloud Run service you wish to use for this deployment.
  The name will be suffixed with -prod and -debug for production and debug services,
  respectively."

MIN_INSTANCES_HELP="  The minimum number of instances running the container at any given time.
  Set to 0 to have Cloud Run scale in automatically based on demand."
MAX_INSTANCES_HELP="  The maximum number of instances Cloud Run will scale up to, if necessary.
  Note that with traffic spikes it's possible for the maximum number of instances
  to be exceeded temporarily."
MEMORY_LIMIT_HELP="  Enter the memory limit for each instance. If you specify higher than 4Gi, you will
  need to allocate a minimum of 2 CPUs, and if you want to allocate 4 CPUs, you will
  need to set a memory limit of at least 2Gi (CPU limits will be prompted from you next)."
CPU_LIMIT_HELP="  Enter the number of CPUs to use for each instance. Options are 1, 2, and 4. If you set
  the memory limit to higher than 4Gi, you must allocate at least 2 CPUs. If you want to
  allocate 4 CPUs, the memory limit must be at least 2Gi."
SAME_SETTINGS="  Your configured settings are the same as the current deployment."
CONFIG_ENV_PATH=".spec.template.spec.containers[0].env[]"
CONFIG_MEMORY_PATH=".spec.template.spec.containers[0].resources.limits.memory"
CONFIG_CPU_PATH=".spec.template.spec.containers[0].resources.limits.cpu"
CONFIG_MAX_SCALE_PATH='.spec.template.metadata.annotations."autoscaling.knative.dev/maxScale"'
CONFIG_MIN_SCALE_PATH='.spec.template.metadata.annotations."autoscaling.knative.dev/minScale"'
REGION_PATH='.metadata.labels."cloud.googleapis.com/location"'
CPU_LIMIT_REGEX="^[124]$"
MEMORY_LIMIT_REGEX="^[1-9]+[0-9]*[MG][Bi]$"
POSITIVE_INT_REGEX="^[1-9]+[0-9]*$"
POSITIVE_INT_OR_ZERO_REGEX="^([1-9]+[0-9]*|0)$"

IP_PREFIX_HELP="Enter the name that you want to call this address"

DOMAIN_LIST_HELP="a single domain name or a comma-delimited list of domain names to use for this certificate"
CERTIFICATE_NAME_HELP="a name for the global SSL certificate"

trap "exit" INT
set -e

generate_suggested() {
  echo "$([[ -z "$1" || "$1" == 'null' ]] && echo "$2" || echo "Current: $1")"
}

get_config() {
  echo "$(gcloud run services describe ${service_prefix} --format=json)"
}

select_region() {
    echo "Выберите регион для создания датасета в BigQuery:"
    echo "[1] asia-east1"
    echo "[2] asia-east2"
    echo "[3] asia-northeast1"
    echo "[4] asia-northeast2"
    echo "[5] asia-northeast3"
    echo "[6] asia-south1"
    echo "[7] asia-south2"
    echo "[8] asia-southeast1"
    echo "[9] asia-southeast2"
    echo "[10] australia-southeast1"
    echo "[11] australia-southeast2"
    echo "[12] europe-central2"
    echo "[13] europe-north1"
    echo "[14] europe-southwest1"
    echo "[15] europe-west1"
    echo "[16] europe-west12"
    echo "[17] europe-west2"
    echo "[18] europe-west3"
    echo "[19] europe-west4"
    echo "[20] europe-west6"
    echo "[21] europe-west8"
    echo "[22] europe-west9"
    echo "[23] me-central1"
    echo "[24] me-west1"
    echo "[25] northamerica-northeast1"
    echo "[26] northamerica-northeast2"
    echo "[27] southamerica-east1"
    echo "[28] southamerica-west1"
    echo "[29] us-central1"
    echo "[30] us-east1"
    echo "[31] us-east4"
    echo "[32] us-east5"
    echo "[33] us-south1"
    echo "[34] us-west1"
    echo "[35] us-west2"
    echo "[36] us-west3"
    echo "[37] us-west4"
    echo "[38] cancel"

    echo "Введите номер региона: "
    read region_number

    case $region_number in
      1)
        region="asia-east1"
        ;;
      2)
        region="asia-east2"
        ;;
      3)
        region="asia-northeast1"
        ;;
      4)
        region="asia-northeast2"
        ;;
      5)
        region="asia-northeast3"
        ;;
      6)
        region="asia-south1"
        ;;
      7)
        region="asia-south2"
        ;;
      8)
        region="asia-southeast1"
        ;;
      9)
        region="asia-southeast2"
        ;;
      10)
        region="australia-southeast1"
        ;;
      11)
        region="australia-southeast2"
        ;;
      12)
        region="europe-central2"
        ;;
      13)
        region="europe-north1"
        ;;
      14)
        region="europe-southwest1"
        ;;
      15)
        region="europe-west1"
        ;;
      16)
        region="europe-west12"
        ;;
      17)
        region="europe-west2"
        ;;
      18)
        region="europe-west3"
        ;;
      19)
        region="europe-west4"
        ;;
      20)
        region="europe-west6"
        ;;
      21)
        region="europe-west8"
        ;;
      22)
        region="europe-west9"
        ;;
      23)
        region="me-central1"
        ;;
      24)
        region="me-west1"
        ;;
      25)
        region="northamerica-northeast1"
        ;;
      26)
        region="northamerica-northeast2"
        ;;
      27)
        region="southamerica-east1"
        ;;
      28)
        region="southamerica-west1"
        ;;
      29)
        region="us-central1"
        ;;
      30)
        region="us-east1"
        ;;
      31)
        region="us-east4"
        ;;
      32)
        region="us-east5"
        ;;
      33)
        region="us-south1"
        ;;
      34)
        region="us-west1"
        ;;
      35)
        region="us-west2"
        ;;
      36)
        region="us-west3"
        ;;
      37)
        region="us-west4"
        ;;
      38)
        echo "Отменено."
        exit 1
        ;;
      *)
        echo "Недопустимый номер региона."
        exit 1
        ;;
    esac

#    echo "Выбран регион: $region"
    # Дальнейшая обработка или передача региона в другую функцию
}
prompt_continue_default_no() {
  while true; do
    printf "$1"
    read confirmation
    confirmation="$(echo "${confirmation}" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "${confirmation}" || "${confirmation}" == 'n' ]]; then
      exit 0
    fi
    if [[ "${confirmation}" == "y" ]]; then
      break
    fi
  done
}





prompt_dataset_prefix() {
  while [[ -z "${dataset_prefix}" || "${dataset_prefix}" == '?' ]]; do
    recommended="bq-streaming"
    suggested="$(
      generate_suggested "${cur_dataset_prefix}" "Recommended: ${recommended}"
    )"
    printf "Dataset Name (${suggested}): "
    read dataset_prefix

    if [[ "${dataset_prefix}" == '?' ]]; then
      echo "${SERVICE_PREFIX_HELP}"
    elif [[ -z "${dataset_prefix}" ]]; then
      if [[ ! -z "${cur_dataset_prefix}" ]]; then
        dataset_prefix="${cur_dataset_prefix}"
      else
        dataset_prefix="${recommended}"
      fi
    fi
  done
}

create_dataset() {
  echo "Create the dataset with name ${dataset_prefix}, press any key to begin..."
  project_id=$(gcloud config list --format 'value(core.project)')
  read -n 1 -s
  bq.cmd --location=${region} mk \
  "${project_id}:${dataset_prefix}"
  read -n 1 -s
}

echo "${WELCOME_TEXT}"
echo""
prompt_dataset_prefix
select_region
echo ""
echo "Your configured settings are"
echo "Dataset Name: ${dataset_prefix}"
echo "Dataset Region: ${region}"
echo ""
prompt_continue_default_no "${WISH_TO_CONTINUE}"
echo "As you wish."
echo ""
create_dataset
echo "Your server deployment is complete."

prompt_table_prefix() {
  while [[ -z "${table_prefix}" || "${table_prefix}" == '?' ]]; do
    recommended="bq-streaming"
    suggested="$(
      generate_suggested "${cur_table_prefix}" "Recommended: ${recommended}"
    )"
    printf "Table Name (${suggested}): "
    read table_prefix

    if [[ "${table_prefix}" == '?' ]]; then
      echo "${SERVICE_PREFIX_HELP}"
    elif [[ -z "${table_prefix}" ]]; then
      if [[ ! -z "${cur_table_prefix}" ]]; then
        table_prefix="${cur_table_prefix}"
      else
        table_prefix="${recommended}"
      fi
    fi
  done
}

create_table() {
  echo "Create the table with name ${table_prefix}, press any key to begin..."
    bq.cmd mk \
  --table \
  --time_partitioning_field event_date \
  "${dataset_prefix}.${table_prefix}" \
  "./stream_schema.json"
  read -n 1 -s
}
echo ""
echo "Next step create table"
prompt_continue_default_no "${WISH_TO_CONTINUE}"
prompt_table_prefix
echo ""
echo "Your configured settings are"
echo "Table Name: ${table_prefix}"
echo ""
prompt_continue_default_no "${WISH_TO_CONTINUE}"
echo "As you wish."
echo ""
create_table
echo ""
echo "Your server deployment is complete."


# ===================начало установки Cloud Run =================
prompt_service_prefix() {
  while [[ -z "${service_prefix}" || "${service_prefix}" == '?' ]]; do
    recommended="gtm-server"
    suggested="$(
      generate_suggested "${cur_service_prefix}" "Recommended: ${recommended}"
    )"
    printf "Service Name (${suggested}): "
    read service_prefix

    if [[ "${service_prefix}" == '?' ]]; then
      echo "${SERVICE_PREFIX_HELP}"
    elif [[ -z "${service_prefix}" ]]; then
      if [[ ! -z "${cur_service_prefix}" ]]; then
        service_prefix="${cur_service_prefix}"
      else
        service_prefix="${recommended}"
      fi
    fi
  done
}

prompt_existing_service() {
  while true; do
    printf "Fetch existing service configuration (you will be prompted for the Region next)? (y/N): "
    read confirmation
    confirmation="$(echo "${confirmation}" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "${confirmation}" || "${confirmation}" == 'n' ]]; then
      break
    fi
    if [[ "${confirmation}" == "y" ]]; then
      config=$(get_config)
      if [[ ! -z ${config} ]]; then
#        cur_policy_script_url="$(echo "${config}" | jq -r ${CONFIG_ENV_PATH}' | select(.name | contains("POLICY_SCRIPT_URL")).value')"
        cur_memory_limit="$(echo "${config}" | jq -r ${CONFIG_MEMORY_PATH})"
        cur_cpu_limit="$(echo "${config}" | jq -r ${CONFIG_CPU_PATH})"
        cur_min_instances="$(echo "${config}" | jq -r ${CONFIG_MIN_SCALE_PATH})"
        cur_max_instances="$(echo "${config}" | jq -r ${CONFIG_MAX_SCALE_PATH})"
        cur_region="$(echo "${config}" | jq -r ${REGION_PATH})"
        if [[ "${cur_min_instances}" == 'null' ]]; then
          cur_min_instances=0
        fi
        break
      else
        service_prefix=''
        prompt_service_prefix
      fi
    fi
  done
}

#prompt_policy_script_url() {
#  while true; do
#    suggested="$(generate_suggested "${cur_policy_script_url}" "Optional")"
#    printf "Policy Script URL (${suggested}): "
#    read policy_script_url
#
#    if [[ "${policy_script_url}" =~ ^[Nn][Oo][Nn][Ee]$ ]]; then
#      policy_script_url="''"
#    elif [[ "${policy_script_url}" == '""' ]]; then
#      policy_script_url="''"
#    fi
#
#    if [[ "$policy_script_url" == '?' ]]; then
#      echo "${POLICY_SCRIPT_HELP}"
#    elif [[ -z "${policy_script_url}" ]]; then
#      if [[ ! -z "${cur_policy_script_url}" && "${cur_policy_script_url}" != 'null' ]]; then
#        policy_script_url="${cur_policy_script_url}"
#      else
#        policy_script_url="''"
#      fi
#      break
#    else
#      break
#    fi
#  done
#}

prompt_memory() {
  while [[ ! "${memory_limit}" =~ ${MEMORY_LIMIT_REGEX} ||
    "${memory_limit}" == '?' || -z "${memory_limit}" ]]; do
    recommended="512Mi"
    suggested="$(
      generate_suggested "${cur_memory_limit}" "Recommended: ${recommended}"
    )"
    printf "Memory Per Instance (${suggested}): "
    read memory_limit
    if [[ "${memory_limit}" == '?' ]]; then
      echo "${MEMORY_LIMIT_HELP}"
    elif [[ -z "${memory_limit}" ]]; then
      if [[ ! -z "${cur_memory_limit}" ]]; then
        memory_limit="${cur_memory_limit}"
      else
        memory_limit="${recommended}"
      fi
    elif [[ ! "${memory_limit}" =~ ${MEMORY_LIMIT_REGEX} ]]; then
      echo " Enter a valid memory unit, e.g. 512Mi"
    fi
  done
}

prompt_cpu_limit() {
  while [[ ! "${cpu_limit}" =~ ${CPU_LIMIT_REGEX} ||
    "${cpu_limit}" == '?' || "${cpu_limit}" -le 0 ]]; do
    recommended="1"
    suggested="$(
      generate_suggested "${cur_cpu_limit}" "Recommended: ${recommended}"
    )"
    printf "CPU Allocation Per Instance (${suggested}): "
    read cpu_limit
    if [[ "${cpu_limit}" == '?' ]]; then
      echo "${CPU_LIMIT_HELP}"
    elif [[ -z "${cpu_limit}" ]]; then
      if [[ ! -z "${cur_cpu_limit}" && "${cur_cpu_limit}" != 'null' ]]; then
        cpu_limit="${cur_cpu_limit}"
      else
        cpu_limit="${recommended}"
      fi
    elif [[ ! "${cpu_limit}" =~ ${CPU_LIMIT_REGEX} ]]; then
      echo "  You can assign 1, 2, or 4 virtual CPUs per instance"
    fi
  done
}

prompt_min_instances() {
  while [[ ! "${min_instances}" =~ ${POSITIVE_INT_OR_ZERO_REGEX} ||
    "${min_instances}" == '?' ]]; do
    recommended="3"
    suggested="$(
      generate_suggested "${cur_min_instances}" "Recommended: ${recommended}"
    )"
    printf "Minimum Number of Servers (${suggested}): "
    read min_instances
    if [[ "${min_instances}" == '?' ]]; then
      echo "${MIN_INSTANCES_HELP}"
    elif [[ -z "${min_instances}" ]]; then
      if [[ ! -z "${cur_min_instances}" && "${cur_min_instances}" != 'null' ]]; then
        min_instances="${cur_min_instances}"
      else
        min_instances="${recommended}"
      fi
    elif [[ ! "${min_instances}" =~ ${POSITIVE_INT_OR_ZERO_REGEX} ]]; then
      echo "  The input must be a positive integer or 0."
    fi
  done
}

prompt_max_instances() {
  while [[ ! "${max_instances}" =~ ${POSITIVE_INT_REGEX} ||
    "${max_instances}" == '?' ||
    "${min_instances}" -gt "${max_instances}" ]]; do
    recommended="6"
    suggested="$(
      generate_suggested "${cur_max_instances}" "Recommended: ${recommended}"
    )"
    printf "Maximum Number of Servers (${suggested}): "
    read max_instances
    if [[ "${max_instances}" == '?' ]]; then
      echo "${MAX_INSTANCES_HELP}"
    elif [[ -z "${max_instances}" ]]; then
      if [[ ! -z "${cur_max_instances}" && "${cur_max_instances}" != 'null' ]]; then
        max_instances="${cur_max_instances}"
      else
        max_instances="${recommended}"
      fi
    elif [[ ! "${max_instances}" =~ ${POSITIVE_INT_REGEX} ]]; then
      echo "  The input must be a positive integer."
    elif [[ "${min_instances}" -gt "${max_instances}" ]]; then
      echo "  The input must be equal or greater than the minimum number of servers."
    fi
  done
}

deploy_production_server() {
#  if [[ "${policy_script_url}" == "''" ]]; then
#    policy_script_url=""
#  fi
  echo "Deploying the production service to ${service_prefix}, press any key to begin..."
  project_id=$(gcloud config list --format 'value(core.project)')
  read -n 1 -s
  prod_url=$(gcloud run deploy ${service_prefix} --image=${IMG_URL} \
  --cpu=${cpu_limit} --allow-unauthenticated --min-instances=${min_instances} \
  --max-instances=${max_instances} --memory=${memory_limit} --region=${cur_region} \
  --set-env-vars project_id=${project_id} --format="value(status.url)" \
  --set-env-vars dataset_id=${dataset_prefix} --format="value(status.url)" \
  --set-env-vars table_id=${table_prefix} --format="value(status.url)" )
}


prompt_service_prefix
prompt_existing_service
#prompt_policy_script_url
prompt_memory
prompt_cpu_limit
prompt_min_instances
prompt_max_instances


echo ""
echo "Your configured settings are"
echo "Service Name: ${service_prefix}"
#echo "Policy Script URL: ${policy_script_url}"
echo "Memory Per Instance: ${memory_limit}"
echo "CPU Allocation Per Instance: ${cpu_limit}"
echo "Minimum Number of Servers: ${min_instances}"
echo "Maximum Number of Servers: ${max_instances}"
if [[ ! -z ${cur_region} ]]; then
  echo "Region: ${cur_region}"
fi

prompt_continue_default_no "${WISH_TO_CONTINUE}"

if [[
#  "${policy_script_url}" == "${cur_policy_script_url}" &&
  "${memory_limit}" == "${cur_memory_limit}" &&
  "${cpu_limit}" == "${cur_cpu_limit}" &&
  "${min_instances}" == "${cur_min_instances}" &&
  "${max_instances}" == "${cur_max_instances}" ]]; then
  same_deployment_settings="true"
else
  same_deployment_settings="false"
fi

if [[ "${same_deployment_settings}" == "true" ]]; then
  echo ""
  echo "${SAME_SETTINGS}"
  prompt_continue_default_no "${WISH_TO_CONTINUE}"
fi

echo "As you wish."

deploy_production_server

echo ""
echo "Your server deployment is complete."
echo ""
echo "Production server test:"
printf "${prod_url}/healthy"
echo ""
# ======== установка cloud run завершена =======================
#=======================Начало создания статического IP========================

prompt_static_ip_prefix() {
  while [[ -z "${ip_prefix}" || "${ip_prefix}" == '?' ]]; do
    recommended="bq-streaming-static-ip"
    suggested="$(
      generate_suggested "${cur_ip_prefix}" "Recommended: ${recommended}"
    )"
    printf "Adress Name (${suggested}): "
    read ip_prefix

    if [[ "${ip_prefix}" == '?' ]]; then
      echo "${IP_PREFIX_HELP}"
    elif [[ -z "${ip_prefix}" ]]; then
      if [[ ! -z "${cur_ip_prefix}" ]]; then
        ip_prefix="${cur_ip_prefix}"
      else
        ip_prefix="${recommended}"
      fi
    fi
  done
}

deploy_static_ip() {
  echo "Deploying the static IP name ${ip_prefix}, press any key to begin..."
  gcloud compute addresses create ${ip_prefix}\
  --global \
  --ip-version=IPV4\
  --network-tier=PREMIUM
  read -n 1 -s
}

get_static_ip() {
  ip_address=$(gcloud compute addresses describe ${ip_prefix} \
  --global \
  --format="get(address)"
    )
}
echo "Create static external IP"
prompt_continue_default_no "${WISH_TO_CONTINUE}"
prompt_static_ip_prefix
echo ""
echo "Your configured settings are"
echo "Service Name: ${ip_prefix}"
prompt_continue_default_no "${WISH_TO_CONTINUE}"
echo "As you wish."
echo ""
deploy_static_ip
echo""
echo "Your ip deployment is complete."
get_static_ip
echo ""
echo "Your ip is ${ip_address} complete."
echo ""
#====================конец установки статичного ip ===========================
#создание сертификата Create an SSL certificate
#
get_certificate_name() {
  while [[ -z "${cert_name}" || "${cert_name}" == '?' ]]; do
    recommended="bq-streaming-cert"
    suggested="$(
      generate_suggested "${cur_cert_name}" "Recommended: ${recommended}"
    )"
    printf "Adress Name (${suggested}): "
    read cert_name

    if [[ "${cert_name}" == '?' ]]; then
      echo "${CERTIFICATE_NAME_HELP}"
    elif [[ -z "${cert_name}" ]]; then
      if [[ ! -z "${cur_cert_name}" ]]; then
        cert_name="${cur_cert_name}"
      else
        cert_name="${recommended}"
      fi
    fi
  done
}

get_domain_list() {
  while [[ -z "${domain_list}" || "${domain_list}" == '?' ]]; do
    printf "Domain Name: "
    read domain_list

    if [[ "${domain_list}" == '?' ]]; then
      echo "${DOMAIN_LIST_HELP}"
    elif [[ -z "${domain_list}" ]]; then
      if [[ ! -z "${cur_domain_list}" ]]; then
        domain_list="${cur_domain_list}"
      fi
    fi
  done
}


deploy_certificate() {
  echo "Deploying the certificat to ${cert_name}, press any key to begin..."
  gcloud compute ssl-certificates create ${cert_name}\
  --global \
  --domains=${domain_list}
  read -n 1 -s
}

get_certificate() {
  cert_list=$(gcloud compute ssl-certificates describe ${cert_name} \
    --global\
    ---format="get(name,managed.status, managed.domainStatus)")
}
echo""
echo "Create SSL-certificate"
prompt_continue_default_no "${WISH_TO_CONTINUE}"
get_certificate_name
get_domain_list
echo ""
echo "Your configured settings are"
echo "Certificate Name: ${cert_name}"
echo "Domain List: ${domain_list}"
prompt_continue_default_no "${WISH_TO_CONTINUE}"
echo "As you wish."
echo ""
deploy_certificate
echo""
echo "Your SSL certificate deployment is complete."
get_certificate
echo ""
echo "Your certificate is ${cert_list} complete."
echo ""















echo ""
exit 0
