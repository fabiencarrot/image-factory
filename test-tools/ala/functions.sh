#!/bin/sh

wait_to_boot() {
    local vm_id=$1
    local ip=$2
    local count=1

    if [ $SLES -eq 1 ]
    then
        count=2
    fi

    if [ $REBOOT -eq 1 ]
    then
        count=1
    fi

    vm_state=`nova list | grep $vm_id | awk '{print $6}'`
    if [ "$vm_state" == "ERROR" ]
    then
    	echo "TEST failed : server in error state"
		return 1
    fi

    if [ $WIN -eq 1 ]
    then
        msg="cloudbase-init stop_service"
    else
        msg="Cloud-init .* finished at"
    fi

    I=$RETRY

    while [[ $I -gt 0 ]]
    do
        n=$(nova console-log $vm_id | grep -i -c "$msg")
        if  [[ $n -lt $count ]]
        then
            echo "  Waiting for cloud-init to finish"
            sleep $SMALL_SLEEP
            I=$(($I - 1))
            continue
        fi


        echo "  cloud-init finished."
        if [[ $WIN -eq 1 ]]
        then
            return 0
        fi

        if ping -w 1 -c 1 $ip &>/dev/null
        then
            return 0
        fi

        echo "TEST failed : server does not ping"
        return 1
    done

    echo "TEST failed : server did not start"
    return 1
}


wait_vm_state() {

    local id=$1
    local state=$2
    local vm_state=`nova list | grep $id | awk '{print $6}'`

    while [ "$vm_state" != $state ]
    do
        sleep $MINI_SLEEP
        vm_state=`nova list | grep $id | awk '{print $6}'`
        if [ "$vm_state" == "ERROR" ]
        then
            return
        fi
    done
}


boot_vm() {

    local sg=$1
    local name=$2
    local key=$3
    local image="$4"
    local flavor=$5
    local args=$6

    ID=`nova boot --flavor $flavor --image "$image" --key-name $key --security-groups $sg --nic net-id=$NETWORK $args $name | grep " id " | awk '{print $4}'`
    wait_vm_state $ID "ACTIVE"
    echo $ID
}

boot_vm_with_port_and_userdata() {

    local sg=$1
    local name=$2
    local key=$3
    local image="$4"
    local flavor=$5
    local port=$6
    local user_data=$7
    ID=`nova boot --flavor $flavor --image "$image" --key-name $key --security-groups $sg --nic port-id=$port --user-data $user_data $name | grep " id " | awk '{print $4}'`
    wait_vm_state $ID "ACTIVE"
    echo $ID

}

create_port() {

    local network=$1
    local sg=$2

    PORT_ID=`neutron port-create $network --security-group $sg| grep " id " | awk '{print $4}'`
    echo $PORT_ID

}

delete_port() {

    local port_id=$1

    neutron port-delete $port_id >> $LOG_FILE 2>&1
    sleep $MINI_SLEEP

}


get_floatingip_id() {
    local ip=$1

    local ip_id=`neutron floatingip-list | grep " $ip " | awk '{print $2}'`
    echo $ip_id

}
create_floating_ip() {

    IP=`neutron floatingip-create $POOL | grep "floating_ip_address" | awk '{print $4}'`
    echo $IP
}

associate_floating_to_vm() {

    local ip=$1
    local vm_id=$2

    nova floating-ip-associate $vm_id $ip >> $LOG_FILE 2>&1

}

associate_floating_to_port() {

    local ip_id=$1
    local port_id=$2

    neutron floatingip-associate $ip_id $port_id >> $LOG_FILE 2>&1
}



delete_floating_ip() {

    local ip=$1

    ID=`neutron floatingip-list | grep $ip | awk '{print $2}'`
    neutron floatingip-delete $ID  >> $LOG_FILE 2>&1
    sleep $MINI_SLEEP
}


create_test_sg() {

    SG_NAME="test-sg-"$RANDOM
    ID=`neutron security-group-create $SG_NAME| grep " id " | awk '{print $4}'`
    neutron security-group-rule-create --direction ingress --protocol tcp --port-range-min 22 --port-range-max 22 $ID  >> $LOG_FILE 2>&1
    neutron security-group-rule-create --direction egress --protocol udp --port-range-min 0 --port-range-max 65535 $ID  >> $LOG_FILE 2>&1

    neutron security-group-rule-create --direction ingress --protocol tcp --port-range-min 3389 --port-range-max 3389 $ID  >> $LOG_FILE 2>&1
    neutron security-group-rule-create --direction ingress --protocol tcp --port-range-min 5985 --port-range-max 5985 $ID  >> $LOG_FILE 2>&1
    neutron security-group-rule-create --direction ingress --protocol tcp --port-range-min 5986 --port-range-max 5986 $ID  >> $LOG_FILE 2>&1
    neutron security-group-rule-create --direction ingress --protocol icmp $ID  >> $LOG_FILE 2>&1
    neutron security-group-rule-create --direction ingress --protocol tcp --port-range-min 3389 --port-range-max 3389 $ID  >> $LOG_FILE 2>&1

    echo $SG_NAME
}

create_keypair() {

    KEY_NAME="key-"$RANDOM
    ssh-keygen -t rsa -f $KEY_NAME -P ""  >> $LOG_FILE 2>&1
    private=`nova keypair-add --pub-key "./$KEY_NAME.pub" $KEY_NAME`
    echo $KEY_NAME
}

delete_keypair() {
    local key=$1

    nova keypair-delete $key >> $LOG_FILE 2>&1
    rm -f $key $key.pub
}

delete_test_sg() {

    local sg=$1

    neutron security-group-delete $sg  >> $LOG_FILE 2>&1
    sleep $MINI_SLEEP
}

function detach_delete_volume() {
    local vm_id=$1
    local volume_id=$2

    nova volume-detach $vm_id $volume_id >> $LOG_FILE 2>&1
    sleep $SMALL_SLEEP
    cinder delete $volume_id >> $LOG_FILE 2>&1
}
function create_attach_volume() {
    local vm_id=$1

    VOLUME_ID=$(cinder create $VOLUME_SIZE | grep " id " | awk '{print $4}')
    V_STATUS=`cinder list | grep $VOLUME_ID | awk '{print $4}'`
    while [ $V_STATUS != "available" ]
    do
        sleep $MINI_SLEEP
	V_STATUS=`cinder list | grep $VOLUME_ID | awk '{print $4}'`
    done
    nova volume-attach $vm_id $VOLUME_ID >> $LOG_FILE 2>&1
    echo $VOLUME_ID
}

ssh_vm_execute_cmd() {
    local key=$1
    local server=$2
    local cmd="$3"

    output=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -t -q -i $key $server $cmd)
    echo "$output"
}


delete_vm() {
    local vm_id=$1

    nova delete $vm_id >> $LOG_FILE 2>&1
    sleep $MINI_SLEEP
}

function tests_with_ssh() {

    echo ""
    echo "Starting basic tests "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=`nova console-log $VM_ID`
        if [ "`echo $out  | grep -i \"cloud-init\"`" ]
        then
            echo "TEST console-log : OK"
        else
            echo "TEST console-log : KO"
        fi

        out=`nova get-spice-console $VM_ID spice-html5 2>&1`
        if [ "`echo $out  | grep \"https://\"`" ]
        then
            echo "TEST get-spice-console : OK"
        else
            echo "TEST get-spice-console : K0"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "root@$IP" "ls")
        if [ "`echo $out | grep 'Please login as the user'`" ]
        then
            echo "TEST no root ssh : OK"
        else
            echo "TEST no root ssh : KO"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "pwd")
        if [ "`echo $out | grep /home/$SSH_USER`" ]
        then
            echo "TEST $SSH_USER login : OK"
        else
            echo "TEST $SSH_USER login : KO"
        fi


        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sudo ls 2>&1")
        if [ "`echo $out | grep 'unable to resolve host'`" ]
        then
            echo "TEST local name resolution : KO"
        else
            echo "TEST local name resolution : OK"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "hostname")
        if [ "`echo $out | grep $VM_NAME`" ]
        then
            echo "TEST hostname : OK"
        else
            echo "TEST hostname : KO"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /etc/cloud/cloud.cfg")
        if [ "`echo $out | grep update-upgrade`" ]
        then
            echo "TEST module  package-update-upgrade-install : OK"
        else
            echo "TEST module  package-update-upgrade-install : KO"
        fi


        DISK_SIZE=`nova flavor-list  | grep " $FLAVOR " | awk '{print $8}'`
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "df -h | grep /dev/vda1" | awk '{print $2}')
        if [ "$out" == $DISK_SIZE"G" ]
        then
            echo "TEST disk size : OK"
        else
            echo "TEST disk size : KO"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "(time host -t A $HOST) 2>&1")
        prev="aa"
        for i in $out
        do
            if [ $prev == "real" ]
            then
                time=`echo $i | sed "s/\r//g"`
                break
            else
                prev=$i
            fi
        done

        if [ "`echo $out | grep \"Host $HOST not found\"`" ]
        then
            echo "TEST dns $time : KO"
	    echo $out
        else
            echo "TEST dns $time : OK"
        fi
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /var/log/auth.log")
        if [ "`echo $out | grep error`" ]
        then
            echo "TEST auth error : KO"
        else
            echo "TEST auth error : OK"
        fi

        if [ $SLES -eq 1 ]
        then
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /etc/sysconfig/bootloader | grep DEFAULT_APPEND")
            echo $out
            if [ "`echo $out | grep  ipv6.disable=1`" ]
            then
                echo "TEST ipv6.disable in /etc/sysconfig/bootloader section DEFAULT_APPEND : OK"
            else
                echo "TEST ipv6.disable in /etc/sysconfig/bootloader section DEFAULT_APPEND : KO"
            fi
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /etc/sysconfig/bootloader | grep FAILSAFE_APPEND")
            if [ "`echo $out | grep  ipv6.disable=1`" ]
            then
                echo "TEST ipv6.disable in /etc/sysconfig/bootloader section FAILSAFE_APPEND : OK"
            else
                echo "TEST ipv6.disable in /etc/sysconfig/bootloader section FAILSAFE_APPEND : KO"
            fi
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /boot/grub/menu.lst")

            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /boot/grub/menu.lst")
            if [ "`echo $out | grep  ipv6.disable=1`" ]
            then
                echo "TEST ipv6.disable in menu.lst : OK"
            else
                echo "TEST ipv6.disable in menu.lst : KO"
            fi
        fi

    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
}

function test_google_dns(){

    echo ""
    echo "Starting google dns absence test "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /run/resolvconf/resolv.conf")
        if [ "`echo $out | grep 8.8.8.8`" ]
        then
            echo "TEST google dns was found in /run/resolvconf/resolv.conf : KO"
        else
            echo "TEST google dns was not found in /run/resolvconf/resolv.conf : OK"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /etc/resolv.conf")
        if [ "`echo $out | grep 8.8.8.8`" ]
        then
            echo "TEST google dns was found in /etc/resolv.conf : KO"
        else
            echo "TEST google dns was not found in /etc/resolv.conf : OK"
        fi
    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP

}

function test_haveged() {

    echo ""
    echo "Starting haveged test "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "ps aux | grep haveged")
        if [ "`echo $out | grep sbin/haveged`" ]
        then
            echo "TEST haveged : OK"
        else
            echo "TEST haveged : KO"
        fi

    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
}

function test_shellshock() {


    echo ""
    echo "Starting shellshock test "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "env VAR='() { :;}; echo Vulnerable' bash -c 'echo Test Bash'")

        if [[ $out =~ .*"Vulnerable".* ]]
        then
            echo "TEST bug shellshock : KO"
        else
            echo "TEST bug shellshock : OK"
        fi

    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP

}

function test_aftershock() {


    echo ""
    echo "Starting aftershock test "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "env var='() {(a)=>\' bash -c \"echo date\"; cat echo; rm -f echo")
        if [[ $out =~ .*"date".* ]]
        then
            echo "TEST aftershock : OK"
        else
            echo "TEST aftershock : KO"
        fi
    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP

}

function test_key() {
    echo ""
    echo "Starting keypair test"
    echo "----------------------"

    SG=$(create_test_sg)


    TEST_KEY=$(create_keypair)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $TEST_KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"

    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $TEST_KEY "$SSH_USER@$IP" "hostname")
        if [ "`echo $out | grep $VM_NAME`" ]
        then
            echo "TEST keypair  : OK"
        else
            echo "TEST keypair  : KO"
        fi
    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
    delete_keypair $TEST_KEY
}

function test_soft_hard_reboot() {

    echo ""
    echo "Starting soft and hard reboot tests"
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        sleep 300
        uptime_before=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP"  "cat /proc/uptime" | awk '{print $1}' | sed "s/\..*//g")
        nova reboot $VM_ID
        REBOOT=1
        sleep $TIMEOUT
        if wait_to_boot $VM_ID $IP
        then
            uptime_after=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /proc/uptime" | awk '{print $1}' | sed "s/\..*//g")
            if [ "$uptime_before" -gt "$uptime_after" ]
            then
                echo "TEST soft reboot  : OK"
            else
                echo "TEST soft reboot  : KO"
            fi

            sleep 300
            uptime_before=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /proc/uptime" | awk '{print $1}' | sed "s/\..*//g")
        fi
        nova reboot --hard $VM_ID
        sleep $TIMEOUT
        if wait_to_boot $VM_ID $IP
        then
            uptime_after=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat /proc/uptime" | awk '{print $1}' | sed "s/\..*//g")

            if [ "$uptime_before" -gt "$uptime_after" ]
            then
                echo "TEST hard reboot  : OK"
            else
                echo "TEST hard reboot  : KO"
            fi
        fi
    fi
    REBOOT=0
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
}


function test_aftershock() {
    echo ""
    echo "Starting aftershock test "
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo " Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "env var='() {(a)=>\' bash -c \"echo date\"; cat echo; rm -f echo")
        if [[ $out =~ .*"date".* ]]
        then
            echo "TEST aftershock : OK"
            else
            echo "TEST aftershock : KO"
        fi
    fi
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP

}

function test_volume() {

    echo ""
    echo "Starting volume attachment test"
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        VOLUME_ID=$(create_attach_volume $VM_ID)
        echo "  Volume $VOLUME_ID created and attached to $VM_ID"
        sleep $SMALL_SLEEP

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "ls /dev/vdb")
        if [ "`echo $out | grep \"/dev/vdb\"`" ]
        then
            echo "TEST attach volume : OK"
        else
            echo "TEST attach volume : KO"
        fi
    fi
    detach_delete_volume $VM_ID $VOLUME_ID
    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
}


function test_rescue() {

    echo ""
    echo "Starting rescue test"
    echo "----------------------"

    SG=$(create_test_sg)

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "touch rescue.txt")
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sync")

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" ls)
        if [ "`echo $out | grep \"rescue.txt\"`" ]
        then
            echo "  Test file in place"
        else
            echo "  Test file not in place"
        fi

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "ls /boot")
        if [ "`echo $out | grep \"extlinux\"`" ]
        then
            FILE_LIST="/etc/fstab /boot/extlinux/extlinux.conf"
        else
            FILE_LIST="/etc/fstab /boot/grub/menu.lst /boot/grub/grub.cfg /boot/grub2/grub.cfg"
        fi

        for F in $FILE_LIST
        do
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "cat $F" 2>&1)
            if [ "`echo $out | grep 'No such file'`" ]
            then
                continue
            fi

            if [ "`echo $out | grep \"/dev/vda1\"`" ]
            then
                echo "  TEST /dev/vda1 path in $F : OK"
            else
                echo "  TEST vda1 path in $F not found: KO"
            fi

            if [ "`echo $out | grep LABEL`" ]
            then
                echo "  TEST found LABEL reference in $F : K0"
            else
                echo "  TEST no LABEL reference in $F : OK"
            fi

            if [ "`echo $out | grep UUID`" ]
            then
                echo "  TEST found UUID reference in $F : K0"
            else
                echo "  TEST no UUID reference in $F : OK"
            fi
        done

        nova rescue $VM_ID >> $LOG_FILE 2>&1
        echo "  Instance $VM_ID rescued"
        sleep $TIMEOUT
        if wait_to_boot $VM_ID $IP
        then
            mount=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sudo mkdir /mnt/disk"  2>&1)
            mount=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sudo mount -o nouuid /dev/vdb1 /mnt/disk" 2>&1)
            if [ "`echo $mount | grep 'wrong fs type'`" ]
            then
                mount=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sudo mount /dev/vdb1 /mnt/disk" 2>&1)
            fi

            sleep $SMALL_SLEEP
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "ls /mnt/disk/home/$SSH_USER/" 2>&1 )

            if [ "`echo $out | grep rescue.txt`" ]
            then
                echo "TEST rescue : OK"
            else
                echo "TEST rescue : KO"
            fi
        fi
    fi

    delete_vm $VM_ID
    delete_test_sg $SG
    delete_floating_ip $IP
}


function test_snashot_flavor() {

    echo ""
    echo "Starting test flavor for instance from snapshot"
    echo "----------------------"

    SG=$(create_test_sg)


    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm $SG $VM_NAME $KEY "$IMAGE" $FLAVOR)
    echo "  Instance $VM_ID started"
    IP=$(create_floating_ip)
    associate_floating_to_vm $IP $VM_ID

    if wait_to_boot $VM_ID $IP
    then
        S_NAME="snapshot-"$RANDOM
        nova image-create $VM_ID $S_NAME >> $LOG_FILE 2>&1
        S_ID=`glance image-list | grep $S_NAME | awk '{print $2}'`

        echo "  Snapshoting vm "$S_ID
        S_STATUS=`glance image-show $S_ID | grep " status " | awk '{print $4}'`

        while [ $S_STATUS != "active" ]
        do
            echo "  Waiting for snapshot $S_ID to be in active state"
            sleep $SMALL_SLEEP
            S_STATUS=`glance image-show $S_ID | grep " status " | awk '{print $4}'`
        done
        echo "  Snapshot status is active"

        VM_S_NAME="vm-"$RANDOM
        VM_S_ID=$(boot_vm $SG $VM_NAME $KEY $S_ID $ALT_FLAVOR)
        echo "  Instance from snapshot $VM_S_ID started"
        S_IP=$(create_floating_ip)
        associate_floating_to_vm $S_IP $VM_S_ID

        if wait_to_boot $VM_S_ID $S_IP
        then
            DISK_SIZE=`nova flavor-list  | grep " $ALT_FLAVOR " | awk '{print $8}'`
            out="0"
            out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$S_IP" "df -h | grep /dev/vda1" | awk '{print $2}')

            if [ $out == $DISK_SIZE"G" ]
            then
                echo "TEST change flavor for snapshot : OK"
            else
                echo "TEST change flavor for snapshot : KO"
            fi
        fi
    fi

    delete_vm $VM_ID
    delete_vm $VM_S_ID
    delete_test_sg $SG
    delete_floating_ip $IP
    delete_floating_ip $S_IP
    glance image-delete $S_ID >> $LOG_FILE 2>&1

}

function tests_cloud_init() {

    echo ""
    echo "Starting cloud-init test"
    echo "----------------------"

    SG=$(create_test_sg)

    PORT_ID=$(create_port $NETWORK $SG)
    IP=$(create_floating_ip)
    IP_ID=$(get_floatingip_id $IP)

    associate_floating_to_port $IP_ID $PORT_ID

    VM_NAME="vm-"$RANDOM
    VM_ID=$(boot_vm_with_port_and_userdata $SG $VM_NAME $KEY "$IMAGE" $FLAVOR $PORT_ID $USER_DATA_FILE)
    echo "  Instance $VM_ID started"
    if wait_to_boot $VM_ID $IP
    then

        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "sudo ls /root/" 2>&1)
        if [ "`echo $out | grep cloud-init.txt`" ]
        then
            echo "TEST cloud-config run-cmd : OK"
        else
            echo "TEST cloud-config run-cmd : KO"
        fi
        out=$(ssh_vm_execute_cmd $PRIVATE_KEY "$SSH_USER@$IP" "emacs --version" 2>&1)

        if [ "`echo $out | grep \"GNU Emacs\"`" ]
        then
            echo "TEST cloud-config packages : OK"
        else
            echo "TEST cloud-config packages : KO"
        fi
    fi

    delete_vm $VM_ID
    delete_port $PORT_ID
    delete_test_sg $SG
    delete_floating_ip $IP

}

run_all_tests() {
    tests_with_ssh
    test_key
    test_volume
    test_rescue
    test_snashot_flavor
    test_soft_hard_reboot
    tests_cloud_init
    test_haveged
    test_shellshock
    test_aftershock
    test_google_dns
}
