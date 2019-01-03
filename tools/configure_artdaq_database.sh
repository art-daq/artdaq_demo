#!/bin/bash
[ -z "$RUNSINCLEANSHELL" ] && exec /bin/env -i RUNSINCLEANSHELL="TRUE" \
 HOME=$HOME \
 DISPLAY=$DISPLAY \
 SHELL=$SHELL \
 TERM=$TERM \
 HOSTNAME="$HOSTNAME" \
 KRB5CCNAME="$KRB5CCNAME" \
 LANG="$LANG" \
 PWD="$PWD" \
 USER="$USER" \
 PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin \
 /usr/bin/bash --noprofile --norc "$0" "$@"


#defines
#def_extra_products=/cvmfs/fermilab.opensciencegrid.org/products/artdaq
def_extra_products=/mnt/sde/products
def_toolsdir_dir=/srcs/artdaq_demo/tools
def_ignore_database="export DAQINTERFACE_FHICL_DIRECTORY=IGNORED"
def_timestamp=$(date -d "today" +"%Y%m%d%H%M%S")
def_usersourcefile=user_sourcefile_example
def_transition_timeout_seconds=120

#commnad line arguments parsing
show_help(){
echo "\

Usage: $(basename $0) [options]
 Examples:
   $(basename $0)
   $(basename $0) --setup-script=./setupARTDAQDEMO
   $(basename $0) --setup-script=./setupARTDAQDEMO --no-db
 Options:
   --help                         This help message
   --no-db                        Do *NOT* use artdaq_database
   --verbose                      Show verbose output
   --setup-script=<script-path>   Path to the setupARTDAQDEMO script (default is $PWD/setupARTDAQDEMO)
   --database-version=<version>   Version of artdaq_database to \"setup\" (default is the latest version)
   --database-qualifiers=<quals>  UPS qualifiers for \"setting-up\" artdaq_database (default is \$MRB_QUALS)
   --database-data-dir=<dir-path> Full path to the \"filesytem\" database data files (default is \$MRB_TOP/database)
   --basedir=<dir-path>           Base directory (default is \$MRB_TOP)
   --toolsdir=<dir-path>          artdaq_demo/tools directory (default is \$MRB_TOP$def_toolsdir_dir)
   --extra-products=<dir-list>    Additional UPS products directories (default is $def_extra_products)

"
}

value_notset="notset"

arg_verbose=0
arg_do_help=0
arg_do_db=1
arg_setup_script=$PWD/setupARTDAQDEMO
arg_database_version=$value_notset
arg_database_quals=$value_notset
arg_database_data_dir=$value_notset
arg_basedir=$value_notset
arg_toolsdir=$value_notset
arg_extra_products=$value_notset
arg_load_configs=0

glb_daqintdir=$value_notset

ret_msg=$value_notset

for opt in "$@"; do case $opt in
    \?*|-h|--help)            arg_do_help=1                     ;;
    --setup-script=*)         arg_setup_script="${opt#*=}"      ;;
    --database-version=*)     arg_database_version="${opt#*=}"  ;;
    --database-qualifiers=*)  arg_database_quals="${opt#*=}"    ;;
    --database-data-dir=*)    arg_database_data_dir="${opt#*=}" ;;
    --extra-products=*)       arg_extra_products="${opt#*=}"    ;;
    --verbose)                arg_verbose=1                     ;;
    --no-db)                  arg_do_db=0                       ;;
    --basedir=*)              arg_basedir="${opt#*=}"           ;;
    --toolsdir=*)             arg_toolsdir="${opt#*=}"          ;;
    --load-configs)           arg_load_configs=1                ;;
    *)                        arg_do_help=1                     ;;
esac; done

if [[ $arg_verbose == 1 ]]; then
  echo "Parsed command-line options:"
  echo "  arg_setup_script     :$arg_setup_script"
  echo "  arg_database_data_dir:$arg_database_data_dir"
  echo "  arg_database_quals   :$arg_database_quals"
  echo "  arg_database_version :$arg_database_version"
  echo "  arg_basedir          :$arg_basedir"
  echo "  arg_toolsdir         :$arg_toolsdir"
  echo "  arg_do_db            :$arg_do_db"
  echo "  arg_do_help          :$arg_do_help"
  echo "  arg_verbose          :$arg_verbose"
  echo "  arg_load_configs     :$arg_load_configs"
  echo "  arg_extra_products   :$arg_extra_products"
  echo
fi

if [[ $arg_do_help == 1 ]]; then
  show_help
  exit 0
fi

#hepler functions
function trim()
{
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

function configure_artdaq_database()
{
    echo "Info: Running configure_artdaq_database()"

    local error_val="ERROR"

    local this_setup_script="$arg_setup_script"
    if [[ ! -f $this_setup_script ]]; then
      ret_msg="Error: \"$this_setup_script\" does not exist."
      return 1		
    fi

    [[ "$arg_basedir" == "$value_notset" ]] && unset arg_basedir
    local this_basedir=${arg_basedir:-$(source $this_setup_script > /dev/null 2>&1 \
          && echo $MRB_TOP || echo $error_val)}
    if [[ ! -d $this_basedir ]]; then
      ret_msg="Error: \"$this_basedir\" does not exist."
       return 2
    fi

    [[ "$arg_database_data_dir" == "$value_notset" ]] && unset arg_database_data_dir
    local this_database_data_dir=${arg_database_data_dir:-$this_basedir/database}

    local this_daqintdir="$this_basedir/DAQInterface"
    if [[ ! -d $this_daqintdir ]]; then
      ret_msg="Error: \"$this_daqintdir\" does not exist."
      return 3
    fi
    glb_daqintdir=$this_daqintdir

    #return is the database directory exists already
    [[ -d $this_database_data_dir ]] && return 0

    [[ "$arg_database_quals" == "$value_notset" ]] && unset arg_database_quals
    local this_database_quals=${arg_database_quals:-$(source $this_setup_script > /dev/null 2>&1 && \
          echo $MRB_QUALS || echo $error_val)}
    if [[ "$this_database_quals" == "$error_val" ]]; then
      ret_msg="Error: \"source $this_setup_script\" did not export MRB_QUALS."
      return 4
    fi

    [[ "$arg_extra_products" == "$value_notset" ]] && unset arg_extra_products
    local this_extra_products=${arg_extra_products:-$def_extra_products}

    if [[ "$this_extra_products" != "$value_notset" && ! -f $this_extra_products/setup ]]; then
      ret_msg="Error: Invalid UPS repository, \"$this_extra_products/setup\" does not exist."
      return 5
    fi

    [[ "$arg_database_version" == "$value_notset" ]] && unset arg_database_version
    local this_database_version=${arg_database_version:-$( \
       if [[ "$this_extra_products" != "$value_notset" ]]; then source $this_extra_products/setup; fi && \
          source $this_setup_script > /dev/null 2>&1 && \
          ups list -aK+ artdaq_database -q $this_database_quals |cut -d" " -f2 |tr -d '"'| sort |tail -1 || echo $error_val)}
    if [[ -z $this_database_version ]] || [[ "$this_database_version" == "$error_val" ]]; then
      ret_msg="Error: artdaq_database with qualifiers $this_database_quals was not found."
      return 6
    fi

    local this_database_upsrepo=$( \
      if [[ "$this_extra_products" != "$value_notset" ]]; then source $this_extra_products/setup; fi && \
         source $this_setup_script > /dev/null 2>&1 && \
         ups list -a artdaq_database $this_database_version -q $this_database_quals |grep -B1 "Version=" | \
         grep "DATABASE="  |cut -d "=" -f 2 | head -1 || echo $error_val)
    this_database_upsrepo=$(trim $this_database_upsrepo)
    if [[ -z $this_database_upsrepo ]] || [[ "$this_database_upsrepo" == "$error_val" ]] || [[ ! -f $this_database_upsrepo/setup ]]; then
      ret_msg="Error: Unable to determine the UPS path for artdaq_database $this_database_version with qualifiers $this_database_quals."
      return 7
    fi

    [[ "$arg_toolsdir" == "$value_notset" ]] && unset arg_toolsdir
    local this_toolsdir=${arg_toolsdir:-"$this_basedir$def_toolsdir_dir"}
    if [[ ! -d $this_toolsdir ]]; then
      ret_msg="Error: \"$this_toolsdir\" does not exist."
      return 8
    fi

    if [[ ! -f $this_toolsdir/xt_cmd.sh ]]; then
      ret_msg="Error: \"$this_toolsdir/xt_cmd.sh\" does not exist."
      return 9
    fi

    if [[ ! -f $this_daqintdir/$def_usersourcefile ]]; then
      ret_msg="Error: \"$this_daqintdir/$def_usersourcefile\" does not exist."
      return 10
    fi

    local this_script_fullpath=$value_notset
    if [[ "$0" == "$BASH_SOURCE" ]];then
      this_script_fullpath=$(readlink --canonicalize-existing $0)
    else
      this_script_fullpath=$BASH_SOURCE
    fi


    if [[ $arg_verbose == 1 ]]; then
      echo "Resolved runtime options:"
      echo "  this_setup_script     :$this_setup_script"
      echo "  this_database_data_dir:$this_database_data_dir"
      echo "  this_database_quals   :$this_database_quals"
      echo "  this_database_version :$this_database_version"
      echo "  this_database_upsrepo :$this_database_upsrepo"
      echo "  this_basedir          :$this_basedir"
      echo "  this_toolsdir         :$this_toolsdir"
      echo "  this_daqintdir        :$this_daqintdir"
      echo "  this_script_fullpath  :$this_script_fullpath"
      echo "  this_extra_products   :$this_extra_products"
      echo
    fi

    echo "Info: Configuring artdaq_database $this_database_version with qualifiers $this_database_quals in $this_database_data_dir."

    [[ ! -f $this_daqintdir/$def_usersourcefile.orig ]] \
       && cp -f $this_daqintdir/$def_usersourcefile{,.orig} || cp -f $this_daqintdir/$def_usersourcefile{.orig,}

    local database_available=$( \
      if [[ -f $this_database_upsrepo/setup ]]; then source $this_database_upsrepo/setup; fi && \
         source $this_setup_script > /dev/null 2>&1 && \
         setup  artdaq_database $this_database_version -q $this_database_quals || echo $error_val)
    if [[ "$database_available" == "$error_val" ]]; then
      ret_msg="Error: Unable to setup artdaq_database $this_database_version with qualifiers $this_database_quals from UPS."
      return 11
    fi

    $( $this_toolsdir/xt_cmd.sh $this_daqintdir --geom '132x33 -sl 2500' \
        -c "source $this_database_upsrepo/setup" \
        -c "export PRODUCTS=\$PRODUCTS:$this_extra_products" \
        -c "source mock_ups_setup.sh" \
        -c "export DAQINTERFACE_USER_SOURCEFILE=$this_daqintdir/$def_usersourcefile" \
        -c 'source $ARTDAQ_DAQINTERFACE_DIR/source_me' \
        -c "setup artdaq_database $this_database_version -q $this_database_quals" \
        -c "RUNSINCLEANSHELL=TRUE CLOSEWINDOWONEXIT=TRUE $this_script_fullpath \
            --load-configs --database-data-dir=$this_database_data_dir" )

}


function delete_database()
{
  echo "Info: Running delete_database()"
  local error_count=0
  local file_ext=".orig"
  ret_msg=""

  ret_msg=""
  if [[ -d $arg_database_data_dir/online_config_db ]]; then
    echo "Info: Deleting database data in $arg_database_data_dir."
    rm -rf $arg_database_data_dir
    if [[ $? != 0 ]]; then
      ret_msg+="Error: Unable to delete $arg_database_data_dir. "
      ((error_count+=1))
    fi
  fi

 local this_daqint_settings_dir=$(dirname $DAQINTERFACE_SETTINGS)

 if [[ -f $this_daqint_settings_dir/boot.txt ]] && [[ $DAQINTERFACE_FHICL_DIRECTORY == "IGNORED" ]]; then
   for f in $(find $this_daqint_settings_dir/ -type f -name "*"$file_ext);do
     if grep -q "export DAQINTERFACE_FHICL_DIRECTORY="  $f; then
      local fn=${f%.*}
      echo "Info: Restoring $fn to its original."
      cp -f $fn{$file_ext,}
      if [[ $? != 0 ]]; then 
        ret_msg+="Error: Unable to restore $f to its original. "
        ((error_count+=1))
      fi
     fi
   done
 fi

 source $this_daqint_settings_dir/$def_usersourcefile || return 0
 if [[ $? != 0 ]]; then 
    ret_msg+="Error: Unable to source $this_daqint_settings_dir/$def_usersourcefile"
    ((error_count+=1))
 fi

 return $error_count
}

function create_schema_fcl()
{
cat > schema.fcl <<EOF
artdaq_processes: [{
collection: SimpleTestConfig 
pattern: "^(?!.*config_includes)(.*/)(.*)(\.fcl$)" 
}] 
artdaq_includes: [{
collection: config_includes 
pattern: "(.*/)config_includes\/(.*)(\.fcl$)" 
}] 
run_history: [{
collection: RunHistory 
pattern: "(.*/)(.*)(\.fcl$)" 
}] 
system_layout: [{
collection: SystemLayout 
pattern: "^(?!.*config_includes)(.*)(schema)(\.fcl$)" 
}]
EOF
}

function load_configs()
{
  [[ $DAQINTERFACE_FHICL_DIRECTORY == "IGNORED" ]] && return 0

  local error_count=0
  local this_tmp_dir=/tmp/load_configs/tmp$def_timestamp
  ret_msg=""

  echo "Info: Running load_configs()"

  [[ ! -f $DAQINTERFACE_USER_SOURCEFILE.orig ]] \
    && cp -f $DAQINTERFACE_USER_SOURCEFILE{,.orig} ||  cp -f $DAQINTERFACE_USER_SOURCEFILE{.orig,}

  local this_database_setup_cmd=$(ups active |grep artdaq_database|awk '{printf "   source %s/setup;setup %s %s %s %s", $8,$1,$2,$5,$6}')
  local match_string=$(cat $DAQINTERFACE_USER_SOURCEFILE|grep "Put code here which sets up the database environment")
  local source_config_dir=$DAQINTERFACE_FHICL_DIRECTORY
  sed -i "s#$match_string#$this_database_setup_cmd#g" $DAQINTERFACE_USER_SOURCEFILE
  sed -i -e '/setup artdaq_database/a\' \
      -e "   export ARTDAQ_DATABASE_URI=filesystemdb://$arg_database_data_dir/online_config_db" $DAQINTERFACE_USER_SOURCEFILE
  sed -i -e '/DAQINTERFACE_FHICL_DIRECTORY=/a\' -e "$def_ignore_database" $DAQINTERFACE_USER_SOURCEFILE

  function setup() {
    local this_ups=$(which ups 2>/dev/null)
    [[ -x $this_ups ]] && source $($this_ups setup "$@") || echo "Error: UPS is not setup."
  }

  source $DAQINTERFACE_USER_SOURCEFILE
  if [[ $? != 0 ]]; then 
    ret_msg+="Error: Unable to source $DAQINTERFACE_USER_SOURCEFILE. "
    ((error_count+=1))
    return $error_count
  fi

  local expected_config_count=0
  echo "Info: ARTDAQ_DATABASE_URI=$ARTDAQ_DATABASE_URI"
  for d in $source_config_dir/*; do
    [[ -d $d ]] || continue

    local config_name=$(basename $d)
    mkdir -p $this_tmp_dir/$config_name
    if [[ $? != 0 ]]; then 
     ret_msg+="Error: Unable to create $this_tmp_dir/$config_name. "
     ((error_count+=1))
    fi

    cp -rf $d/*.fcl $this_tmp_dir/$config_name/
    if [[ $? != 0 ]]; then 
      ret_msg+="Error: Unable to copy $d into $this_tmp_dir/$config_name. "
      ((error_count+=1))
    fi

    cd $this_tmp_dir

    create_schema_fcl

    echo "Info: Importing $config_name"
    local message=$(conftool.py  importConfiguration $config_name 2>&1)
    if [[ ! $message =~ ^.*True$ ]]; then 
      echo "Error: Unable to import \"$config_name\"."
      ret_msg+="Error: Unable to import the \"$config_name\" configuration into ardaq_database. "
      ret_msg+="Details: $message. "
      ((error_count+=1))
    fi

    ((expected_config_count+=1))

    cd ..

    if [[ "$this_tmp_dir" == "/tmp/load_configs/tmp$def_timestamp" ]]; then
      rm -rf $this_tmp_dir
      if [[ $? != 0 ]]; then 
        ret_msg+="Error: Unable to delete files in  $this_tmp_dir. "
        ((error_count+=1))
      fi
    fi
  done

  local actual_config_count=$(conftool.py getListOfAvailableRunConfigurations |wc -l)

  if [[ $actual_config_count !=  $expected_config_count ]]; then 
    ret_msg+="Error: Not all configurations were imported into artdaq_database; expected,actual=$expected_config_count,$actual_config_count . "
    echo "Error: Not all configurations were imported into artdaq_database; expected,actual=$expected_config_count,$actual_config_count."
    ((error_count+=1))
  fi

  echo "Info: Available run configurations:"
  conftool.py getListOfAvailableRunConfigurations
  echo "Info: Finished load_configs()"

  return $error_count
}

function stop_daqinterface_if_running(){
    local error_count=0
    ret_msg=""

    local this_setup_script="$arg_setup_script"
    if [[ ! -f $this_setup_script ]]; then
      ret_msg="Error: \"$this_setup_script\" does not exist."
      return 1
    fi

    [[ "$arg_basedir" == "$value_notset" ]] && unset arg_basedir
    local this_basedir=${arg_basedir:-$(source $this_setup_script > /dev/null 2>&1 \
          && echo $MRB_TOP || echo $error_val)}
    if [[ ! -d $this_basedir ]]; then
      ret_msg="Error: \"$this_basedir\" does not exist."
       return 2
    fi

    local this_daqintdir="$this_basedir/DAQInterface"
    if [[ ! -d $this_daqintdir ]]; then
      ret_msg="Error: \"$this_daqintdir\" does not exist."
      return 3
    fi

    glb_daqintdir=$this_daqintdir

    cd $glb_daqintdir

    #"current_state:call_transition_funct:new_state:transition_timeout"
    declare -a daqifc_fsm_map=(
    "running:call_stop:ready,stopped:$def_transition_timeout_seconds"
    "ready:call_terminate:terminated:$def_transition_timeout_seconds"
    "stopped:call_terminate:terminated:$def_transition_timeout_seconds"
    "booted:call_terminate:terminated:$def_transition_timeout_seconds"
    "configured:call_terminate:terminated:$def_transition_timeout_seconds"
    "configuring:call_terminate:terminated:$def_transition_timeout_seconds")

    function setup() {
      local this_ups=$(which ups 2>/dev/null)
      [[ -x $this_ups ]] && source $($this_ups setup "$@") || echo "Error: UPS is not setup."
    }

    local daqifc_transition=$value_notset
    function get_daqifc_transition() {
      daqifc_transition=$value_notset

      for entry  in ${daqifc_fsm_map[*]}; do
        if [[ $entry =~ ^$1:.*$ ]];then
          daqifc_transition=$entry
          return 0
        fi
      done
      return 1
    }

    function wait_for_state(){
      local abort_timestamp=$(( $(date +%s) + $2 ))

      if [[ "$#" != 2 ]]; then
        echo "Error: wait_for_state expects two arguments espected_state and wait_timeout in seconds"
        return 1
      fi

      while [[ $abort_timestamp < $(date +%s) ]]; do
        sleep 1
        res=$( status.sh | tail -1 | tr "'" " " | awk '{print $2}' )
        if [[ "$res" == "" ]]; then
          sleep 2
          unset DAQINTERFACE_STANDARD_SOURCEFILE_SOURCED
          source $ARTDAQ_DAQINTERFACE_DIR/source_me > /dev/null
        fi

        if [[ "$res" == "$1" ]]; then
         echo "Info: Current DAQInterface state is $res"
         return 0
        fi
       done

       return 2
    }


    function call_stop() {
      send_transition.sh stop
      wait_for_state "$@"
      return $?
    }

    function call_terminate {
      send_transition.sh terminate
      wait_for_state "$@"
      return $?
    }

    function call_kill_daqinterface(){
      kill_daqinterface_on_partition.sh $DAQINTERFACE_PARTITION_NUMBER
      return 0
    }

    source $glb_daqintdir/mock_ups_setup.sh
    export DAQINTERFACE_USER_SOURCEFILE=$glb_daqintdir/$def_usersourcefile
    source $ARTDAQ_DAQINTERFACE_DIR/source_me > /dev/null

    if [[ $( which listdaqinterfaces.sh >/dev/null 2>&1; echo $? ) != 0 ]]; then
      echo "Error: listdaqinterfaces.sh was not setup."
      return 1
    fi

    if [[ $( which status.sh >/dev/null 2>&1; echo $? ) != 0 ]]; then
      echo "Error: status.sh was not setup."
      return 2
    fi

    if [[ $( which send_transition.sh >/dev/null 2>&1; echo $? ) != 0 ]]; then
      echo "Error: send_transition.sh  was not setup."
      return 2
    fi

    if [[ $( listdaqinterfaces.sh 2>/dev/null ) == "No instances of DAQInterface are up" ]]; then
       echo "Info: No instances of DAQInterface are up."
       return 0
    fi

    if [[ $(listdaqinterfaces.sh 2>/dev/null  |grep "$USER in partition $DAQINTERFACE_PARTITION_NUMBER listening" |wc -l) == 0 ]]; then
      echo "Info: No instances of DAQInterface are up in partition $DAQINTERFACE_PARTITION_NUMBER."
      return 0
    fi

    local current_state=$( status.sh | tail -1 | tr "'" " " | awk '{print $2}' )
    echo "Info: Stopping DAQInterface in partition $DAQINTERFACE_PARTITION_NUMBER. Current DAQInterface state is $current_state."

    local should_continue=TRUE
    while [[ "$should_continue" == "TRUE" ]]; do
      get_daqifc_transition $current_state
      if [[ $? !=  0 ]]; then
        should_continue="FALSE"
        echo "Error: State \"$current_state\" is not declared in the daqifc_fsm_map."
      fi

      local transition_function=$(echo $daqifc_transition | cut -d ":" -f 2)
      local expected_state=$(echo $daqifc_transition | cut -d ":" -f 3)
      local transition_timeout_seconds=$(echo $daqifc_transition | cut -d ":" -f 4)

echo   eval "$transition_function $expected_state $transition_timeout_seconds"
      eval "$transition_function $expected_state $transition_timeout_seconds"
      if [[ $? != 0 ]] || [[ "$expected_state" == "terminateed" ]]; then
        should_continue="FALSE"
        kill_daqinterface_on_partition.sh $DAQINTERFACE_PARTITION_NUMBER
      fi

     echo "Info: Stopped DAQInterface in partition $DAQINTERFACE_PARTITION_NUMBER."
     return 0
   done
}

function disable_database() 
{
  local error_count=0
  ret_msg=""

  function setup() { :; }
  source $glb_daqintdir/mock_ups_setup.sh
  source $glb_daqintdir/$def_usersourcefile

  if [[ $DAQINTERFACE_FHICL_DIRECTORY != "IGNORED" ]]; then
     echo "Info: artdaq_database is alreday disabled."
     return 0
  fi

  echo "Info: Running disable_database()"

  sed -i "/$def_ignore_database/d" $glb_daqintdir/$def_usersourcefile
  if [[ $? != 0 ]]; then 
    ret_msg+="Error: Unable to disable artdaq_database. "
    ((error_count+=1))
  else
     echo "Info: artdaq_database is now disabled."
  fi

  return $error_count
}

function enable_database()
{
  local error_count=0
  ret_msg=""

  function setup() { :; }
  source $glb_daqintdir/mock_ups_setup.sh
  source $glb_daqintdir/$def_usersourcefile

  if [[ $DAQINTERFACE_FHICL_DIRECTORY == "IGNORED" ]]; then
     echo "Info: artdaq_database is alreday enabled."
     return 0
  fi

  echo "Info: Running enable_database()"

  sed -i -e '/DAQINTERFACE_FHICL_DIRECTORY=/a\' -e "$def_ignore_database" $glb_daqintdir/$def_usersourcefile
  if [[ $? != 0 ]];then
     ret_msg+="Error: Unable to enable artdaq_database. "
     ((error_count+=1))
  else
    echo "Info: artdaq_database is now enabled."
  fi

  return $error_count
}

## main program
if [[ $arg_load_configs == 0 ]]; then
  configure_artdaq_database
  if [[ $? != 0 ]];then
   [[ $arg_verbose == 1 ]] &&  echo $ret_msg
   [[ "$0" != "$BASH_SOURCE" ]] && return 1 ||exit 1
  fi

  stop_daqinterface_if_running
  if [[ $arg_do_db == 1 ]]; then
    enable_database
      if [[ $? != 0 ]];then
        [[ $arg_verbose == 1 ]] &&  echo $ret_msg
        [[ "$0" != "$BASH_SOURCE" ]] && return 2 ||exit 2
      fi
    else
      disable_database
      if [[ $? != 0 ]];then
        [[ $arg_verbose == 1 ]] && echo $ret_msg
        [[ "$0" != "$BASH_SOURCE" ]] && return 3 ||exit 3
      fi
  fi
else
   delete_database
   if [[ $? != 0 ]];then
      #[[ $arg_verbose == 1 ]] && 
      echo $ret_msg
   else
    load_configs
    error_count=$?
    if [[ $error_count != 0 ]];then
       #[[ $arg_verbose == 1 ]] && echo $ret_msg
       echo "Info: $error_count errors were reported."
    else
       [[ $CLOSEWINDOWONEXIT == "TRUE" ]] && kill -INT $(ps -o ppid= $(ps -o ppid= $$))
    fi

    sleep 5
    [[ $CLOSEWINDOWONEXIT == "TRUE" ]] && kill -INT $(ps -o ppid= $(ps -o ppid= $$))
   fi
fi

[[ "$0" != "$BASH_SOURCE" ]] && return 0 ||exit 0 
