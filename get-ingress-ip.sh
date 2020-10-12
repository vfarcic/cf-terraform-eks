unset INGRESS_HOST

while [ "$INGRESS_HOST" = "" ]; do
    export INGRESS_HOSTNAME=$(kubectl \
        --namespace ingress-nginx \
        get svc ingress-nginx-controller \
        --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")
    export INGRESS_HOST=$(\
        dig +short $INGRESS_HOSTNAME \
        | tail -1)
    sleep 1
done

echo $INGRESS_HOST
