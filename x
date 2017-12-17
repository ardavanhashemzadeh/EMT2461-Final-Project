#!/usr/bin/expect
# December 17 2017
# Ardavan Hashemzadeh
# Receive Doorbel from Arduino
# while linphone is running
# Initiate call when tiggered
# Answer authorized incoming call
# Instruct Arduino to Actuate servo motor by code in call

set timeout 30
set AudioDev hw:1,0
set TriggerLevel 0.2
set SampleDuration 2
set DetectCallDuration 2
set uri [lindex $argv 0]
proc log {message \
        {port 30181} \
        {server logs.papertrailapp.com} \
        {logfile ioti.log}} {
  exec logger "$message" -n $server -P $port -t IoTi
  exec /bin/bash -c "echo `date` $message >> $logfile"
}
proc snap {} {
  log "Taking snapshot"
  set TimeStamp [exec /bin/bash -c {date +"%Y-%m-%d_%H%M%S"}]
  exec /bin/bash -c "fswebcam -q -r 1920x1200 -S 2 $TimeStamp.jpg"
  return $TimeStamp.jpg
}
proc offhook {puri} {
  set timeout -1
  while true {
    expect {
      -re {Syntax error} {break}
      -re {Call .+ error} {break}
      -re {Call .+ ended (No error)} {break}
      -re {Call .+ connected} {send "camera on\r"}
      "Receiving tone 1 from <$puri>" {exec /bin/bash -c "screen -r -X stuff 1"}
    }
  }
}
proc detectdoorbell {} {
exec /bin/bash -c "screen -r -X hardcopy bt"
return [ exec /bin/bash -c "awk '/./{line=\$0} END{print line}' bt | awk '//{print (\$1>=1)?1:0'}" ]
}
exec /bin/bash -c "export AUDIODEV=$AudioDev"
exec screen -dmS bt /dev/rfcomm0 9600
spawn linphonec -C
expect {
  -re {Registration .+ successful} {log "Registration successful"}
  -re {Registration .+ failed} {send "quit\r";log "Registration failed, exiting";exit}
}
while true {
  if { [detectdoorbell] } {
    log "Doorbell detected"
    exec uploader/./uploader [snap]
    send "call $uri\r"
    offhook $uri
  } else {
    set timeout $DetectCallDuration
    expect "call from <$uri>" {
      log "Call from $uri detected"
      exec uploader/./uploader [snap]
      send "answer\r"
      offhook $uri
    }
  }
}
