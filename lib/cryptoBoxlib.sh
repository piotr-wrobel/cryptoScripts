#!/bin/bash

    VERSION="0.5.0"

    G="\033[1;32m";
    Y="\033[1;33m";
    R="\033[0;31m";
    N="\033[0;39m";

    BOXES_PATH="${HOME}/.cryptoBox/boxes"
    MOUNT_PATH="${HOME}/mnt"

    function notification ()
    {
        echo -e "$G" "\n[+] $1" "$N"
    };

    function warning ()
    {
        echo -e "$Y" "\n[-] $1" "$N"
    };

    function error ()
    {
        echo -e "$R" "\n[!] $1" "$N"
    };

    function message ()
    {
        echo -e "$G" "\n[*] $1" "$N"
    };

    function version ()
    {
      message  "cryptoBox version ${VERSION}"
    };

    function help ()
    {
      version
      echo;echo
      echo "Options:"
      echo "-o/--open <boxname>   Open an existing crypto box"
      echo "-c/--close <boxname>  Close the open crypto box"
      echo "-n/--new <boxname>    Create new crypto box"
      echo "-s/--status <boxname> Status of crypto box/boxes"
      echo "-r/--remove <boxname> Permanent removal of crypto box"
      echo "-h/--help             Show this help message"
      echo "-v/--version          cryptoBox version"
      echo
    };

    function is_mounted ()
    {
        COUNT=`mount | grep "${MOUNT_PATH}/${vol_name} " | wc -l`;
        if [[ ${COUNT} -lt 1 ]]; then
          return 0
        else
          return 1
        fi
    }

    function is_unlocked ()
    {
      COUNT=`sudo dmsetup ls | grep "^${vol_name}.(" | wc -l`;
      if [[ ${COUNT} -lt 1 ]]; then
        return 0
      else
        return 1
      fi
    }

    function checkDirectories ()
    {
      if [[ ! -d ${BOXES_PATH} ]]; then
        mkdir -p ${BOXES_PATH}
      fi
      if [[ ! -d ${MOUNT_PATH} ]]; then
        mkdir -p ${MOUNT_PATH}
      fi
    }

    function nameVol ()
    {
        checkDirectories

        if [[ -n $2 ]]; then
          vol_name="$2"
        else
          read -p "Name of encrypted box (e.g., "mybox", "valut"): " vol_name;
        fi

        if [[ ! -n "${vol_name}" ]]; then
            full_vol_name='encryptedBox.box';
            vol_name='encryptedBox'
        else
          full_vol_name="${vol_name}.box"
        fi
        case $1 in
          open)
            if [[ ! -f "${BOXES_PATH}/${full_vol_name}" ]]; then
              warning "Sorry, but box \"${vol_name}\" doesn't exist...."
              exit 0;
            fi
          ;;
          remove)
            if [[ ! -f "${BOXES_PATH}/${full_vol_name}" ]]; then
              warning "Sorry, but box \"${vol_name}\" doesn't exist...."
              exit 0;
            fi
          ;;
          new)
          if [[ -f "${BOXES_PATH}/${full_vol_name}" ]]; then
            warning "Sorry, but box \"${vol_name}\" already exist !!!"
            exit 0;
          fi
          ;;
          close)
          ;;
          *)
            error "ERROR: Undefinied option in nameVol() calling !"
            exit 0;
          ;;
        esac
    };

    function nameKey ()
    {
        read -p "Name of Key file (e.g., "master.keyfile", "image.jpg"): " key_file;
        if [[ ! -n "${key_file}" ]]; then
            key_file='master.keyfile';
        fi
    };

    function nameSize ()
    {
        read -p "Choose volume size (e.g., 10G, 200M): " vol_size;
        if [[ ! -n "${vol_size}" ]]; then
            vol_size='1G';
        fi
    };

    function ddZero ()
    {
        dd if=/dev/zero of="${BOXES_PATH}/${full_vol_name}" bs=1 count=0 seek="${vol_size}"
        if [[ $? -eq 0 ]]; then
          notification "Empty volume created."
        else
          warning "Operation aborted due to an error !"
          exit;
        fi
    };

    function ddRandom ()
    {
        dd if=/dev/urandom of="${BOXES_PATH}/${key_file}" bs=4096 count=1 && notification "Key file successfully created."
    };

    function encryptCon ()
    {
        #sudo cryptsetup -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat "${BOXES_PATH}/${full_vol_name}" "${BOXES_PATH}/${key_file}" && notification "Encrypted box created."
        sudo cryptsetup -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat "${BOXES_PATH}/${full_vol_name}"
        if [[ $? -eq 0 ]]; then
          notification "Encrypted box created."
        else
          warning "Operation aborted due to an error !"
          exit;
        fi
    };

    function encryptOpen ()
    {
        #sudo cryptsetup luksOpen "${full_vol_name}" "$vol_name" --key-file "${BOXES_PATH}/${key_file}" && notification "Volume unlocked."
        is_unlocked;
        if [[ $? -eq 1 ]]; then
          warning "Box \"${vol_name}\" is already open !"
        else
          sudo cryptsetup luksOpen "${BOXES_PATH}/${full_vol_name}" "${vol_name}"
          if [[ $? -eq 0 ]]; then
            notification "Volume unlocked."
          else
            warning "Operation aborted due to an error !"
            exit;
          fi
        fi
    };

    function encryptClose ()
    {
      is_unlocked;
      if [[ $? -eq 0 ]]; then
        warning "Box \"${vol_name}\" is not open !"
      else
        sudo dmsetup remove /dev/mapper/"${vol_name}"
        if [[ $? -eq 0 ]]; then
          notification "Box closed."
        else
          warning "Operation aborted due to an error !"
          exit;
        fi
      fi
    };

    function mkfsFormat ()
    {
        sudo mkfs.ext4 /dev/mapper/"${vol_name}"
        if [[ $? -eq 0 ]]; then
          notification "Volume formatted."
        else
          warning "Operation aborted due to an error !"
          exit;
        fi
    };

    function mountDir ()
    {
      if [[ ! -d "${MOUNT_PATH}/${vol_name}" ]]; then
        mkdir -p "${MOUNT_PATH}/${vol_name}"
      fi
      is_mounted;
      if [[ $? -eq 1 ]]; then
        warning "Box \"${vol_name}\" is already mounted !"
      else
        sudo mount /dev/mapper/"${vol_name}" "${MOUNT_PATH}/${vol_name}/"
        if [[ $? -eq 0 ]]; then
          notification "Volume mounted."
        else
          warning "Operation aborted due to an error !"
          exit;
        fi
      fi
    };

    function umountDir ()
    {
      is_mounted;
      if [[ $? -eq 0 ]]; then
        warning "Box \"${vol_name}\" is not mounted !";
      else
        sudo umount "${MOUNT_PATH}/${vol_name}/"
        if [[ $? -eq 0 ]]; then
          notification "Volume umounted."
        else
          warning "Operation aborted due to an error !";
          exit;
        fi
      fi
    }

    function volPerm ()
    {
      UGROUP=`id -ng`
      sudo chown -R "$USER":"$UGROUP" "${MOUNT_PATH}/${vol_name}"
      if [[ $? -eq 0 ]]; then
        notification "Volume permissions set."
      else
        warning "Operation aborted due to an error !"
        exit 0;
      fi
    };

    function _boxesStatus ()
    {
      if [[ -f "${BOXES_PATH}/${vol_name}.box" ]]; then
        size="$(ls -lh "${BOXES_PATH}/${vol_name}.box" | cut -d' ' -f5)"
      fi
      is_unlocked
      if [[ $? -eq 1 ]]; then
        STATUS="unlocked,"
      else
        STATUS="locked,"
      fi
      is_mounted
      if [[ $? -eq 1 ]]; then
        STATUS="${STATUS}mounted (in ${MOUNT_PATH}/${vol_name})"
      else
        STATUS="${STATUS}unmounted"
      fi
      printf ' -> %-15s %s\n' "$vol_name ($size)" "status:$STATUS"
    }

    function boxesStatus ()
    {
      if [[ -n "${1}" ]]; then
        if [[ ! -f "${BOXES_PATH}/${1}.box" ]]; then
          warning "Sorry, but box \"${1}\" doesn't exist....";
          exit 0;
        else
          message "Status of selected box:";
          vol_name="${1}"
          _boxesStatus
        fi
      else
        if [[ "$(ls -A ${BOXES_PATH})" ]]; then
          message "Status of finded boxes:"
          for BOX in $(ls ${BOXES_PATH}/*.box)
          do
            BOX=$(basename -- "${BOX}")
            vol_name="${BOX%.*}"
            _boxesStatus
          done
        else
          message "You don't have any boxes yet !";
        fi
      fi
      echo
    };

    function removeBox ()
    {
      is_mounted;
      if [[ $? -eq 1 ]]; then
        warning "Box \"${vol_name}\" is already mounted !";
        exit;
      fi

      is_unlocked;
      if [[ $? -eq 1 ]]; then
        warning "Box \"${vol_name}\" is already open !";
        exit;
      fi

      read -p "Are you sure? Type \"yes\" in uppercase: " confirmation;
      if [[ ${confirmation} != "YES" ]]; then
        error "Box removal aborted !";
      else
        rm "${BOXES_PATH}/${full_vol_name}" && notification "Box \"${vol_name}\" has been removed !"
        rm -d "${MOUNT_PATH}/${vol_name}" && notification "Mount point \"${MOUNT_PATH}/${vol_name}\" has been removed !"
      fi
    };
