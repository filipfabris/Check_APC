# Check_APC
Starting script for checking Backup power UPS

## Usage:
```
check_apc.py -H host_ip -C community_password -l command
```

Example input:
```
check_apc.py -H xx.xxx.xxx.xx -C xxxxxxx -l manufacturer
```

Example output:
```
{'1.3.6.1.4.1.534.1.1.1.0': 'EATON'}
```

## Perl and Python script

### Python
1.) Step\
`Define oids`
oid_manufacturer = "1.3.6.1.4.1.534.1.1.1.0"`

2.) Step \
 Inside  `def execute(self):` define function for your new command and oid

### Perl
#### Modification of `check_apc.pl` from [Nagios Exchange](https://exchange.nagios.org/directory/Plugins/Hardware/UPS/APC/check_apc-2Epl/details)
1.) Step\
`Define oids`
oid_manufacturer = "1.3.6.1.4.1.534.1.1.1.0"`

2.) Step \
 Inside  `switch case` define case for your new command and oid



