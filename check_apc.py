#! /usr/bin/python

from pysnmp import hlapi
import getopt
import sys

#Define oids
oid_manufacturer = "1.3.6.1.4.1.534.1.1.1.0"


class CheckAPC:

    help = """ Usage:
            -H  Address of hostname of UPS (required)
            -C  SNMP community string (required)
            -l  Command (optional, see command list)
            -p  SNMP port (optional, defaults to port 161)

            Commands (supplied with -l argument):
            
                manufacturer
                    manufacturer details

            Example:
            script_name -H ups1.domain.local -C public -l manufacturer"""

    def __init__(self):
        self.snmp_host = None
        self.snmp_community = None
        self.snmp_port = None
        self.command = None
        self.setup()

    def setup(self):
        argv = sys.argv[1:]
        # print(argv)

        try:
            opts, args = getopt.getopt(argv, "H:C:l:p:t:w:c:hu")
        except getopt.GetoptError as err:
            print(str(err).upper())
            return

        for opt, arg in opts:
            if opt in ['-H']:
                self.snmp_host = arg
            elif opt in ['-C']:
                self.snmp_community = hlapi.CommunityData(arg)
            elif opt in ['-p']:
                self.snmp_port = arg
            elif opt in ['-l']:
                self.command = arg

        if self.snmp_host is None or self.snmp_community is None:
            print("snmp_host -H or snmp_community -C is not defined")
            exit(1)

        if self.command is None:
            print("command -l is not defined")
            print(self.help)
            exit(2)

        self.execute()

    def execute(self):
        if self.command == "manufacturer":
            print(self.get(self.snmp_host, [oid_manufacturer], self.snmp_community))
        else:
            print(self.command + "is not valid command")
            exit(3)
        return

    @staticmethod
    def construct_object_types(list_of_oids):
        object_types = []
        for oid in list_of_oids:
            object_types.append(hlapi.ObjectType(hlapi.ObjectIdentity(oid)))
        return object_types

    @staticmethod
    def cast(value):
        try:
            return int(value)
        except (ValueError, TypeError):
            try:
                return float(value)
            except (ValueError, TypeError):
                try:
                    return str(value)
                except (ValueError, TypeError):
                    pass
        return value

    def fetch(self, handler, count):
        result = []
        for i in range(count):
            try:
                error_indication, error_status, error_index, var_binds = next(handler)
                if not error_indication and not error_status:
                    items = {}
                    for var_bind in var_binds:
                        items[str(var_bind[0])] = self.cast(var_bind[1])
                    result.append(items)
                else:
                    raise RuntimeError('Got SNMP error: {0}'.format(error_indication))
            except StopIteration:
                break
        return result

    def get(self, target, oids, credentials, port=161, engine=hlapi.SnmpEngine(), context=hlapi.ContextData()):
        handler = hlapi.getCmd(
            engine,
            credentials,
            hlapi.UdpTransportTarget((target, port)),
            context,
            *self.construct_object_types(oids)
        )
        return self.fetch(handler, 1)[0]


def main():
    apc = CheckAPC()


if __name__ == "__main__":
    main()
