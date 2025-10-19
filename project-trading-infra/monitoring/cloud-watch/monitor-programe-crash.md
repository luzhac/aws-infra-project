monitor two python script crash.

```
# heartbeat.py
import time, json, threading, os, sys, boto3, requests
from datetime import datetime, timezone
from botocore.exceptions import ClientError

def get_region():
   
    try:
        r = requests.get(
            "http://169.254.169.254/latest/dynamic/instance-identity/document",
            timeout=1,
        )
        return r.json().get("region", "us-east-1")
    except Exception:
        return os.environ.get("AWS_REGION", "us-east-1")

class Heartbeat:
    def __init__(self, log_group="HeartbeatLogs", interval=60):
        self.region = get_region()
        self.program = os.path.basename(sys.argv[0]) or "unknown"
        self.client = boto3.client("logs", region_name=self.region)
        self.log_group = log_group
        self.log_stream = self.program
        self.interval = interval
        self._stop = threading.Event()
        self._seq = None
        threading.Thread(target=self._ensure_resources, daemon=True).start()

    def _ensure_resources(self):
        try:
            self.client.create_log_group(logGroupName=self.log_group)
        except self.client.exceptions.ResourceAlreadyExistsException:
            pass
        try:
            self.client.create_log_stream(
                logGroupName=self.log_group, logStreamName=self.log_stream
            )
        except self.client.exceptions.ResourceAlreadyExistsException:
            pass

    def _send_once(self):
        msg = {
            "program": self.program,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "status": "alive",
        }
        try:
            kwargs = dict(
                logGroupName=self.log_group,
                logStreamName=self.log_stream,
                logEvents=[
                    {"timestamp": int(time.time() * 1000), "message": json.dumps(msg)}
                ],
            )
            if self._seq:
                kwargs["sequenceToken"] = self._seq
            resp = self.client.put_log_events(**kwargs)
            self._seq = resp.get("nextSequenceToken")
            return True
        except ClientError:
            return False

    def start(self):
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        while not self._stop.is_set():
            self._send_once()
            time.sleep(self.interval)

    def stop(self):
        self._stop.set()

```

``` 
aws logs put-metric-filter \
  --region $(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region) \
  --log-group-name HeartbeatLogs \
  --filter-name trade_binance_q_trade_heartbeat_filter \
  --filter-pattern '  "q_get_symbol"' \
  --metric-transformations \
      metricName=trade_binance_q_trade_heartbeat,metricNamespace=Custom/Heartbeat,metricValue=1,defaultValue=0
``` 

aws sns create-topic --name HeartbeatAlertTopic
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-2:173381466759:HeartbeatAlertTopic \
  --protocol email \
  --notification-endpoint a@gmail.com


aws cloudwatch put-metric-alarm \
  --alarm-name trade_binance_q_trade_heartbeat_missing \
  --namespace Custom/Heartbeat \
  --metric-name trade_binance_q_trade_heartbeat \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --treat-missing-data breaching \
  --alarm-actions arn:aws:sns:eu-west-2:173381466759:HeartbeatAlertTopic

