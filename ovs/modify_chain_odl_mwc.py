#!/usr/bin/python
import requests, json
from requests.auth import HTTPBasicAuth
from string import Template
import time
import os

controller = Template("$ODL_CONTROLLER").substitute(os.environ)
DEFAULT_PORT = '8181'

USERNAME = 'admin'
PASSWORD = 'admin'

CLASSIFIER1_IP = Template("$CLASSIFIER1_IP").substitute(os.environ)
SFF1_IP = Template("$SFF1_IP").substitute(os.environ)
SF1_IP = Template("$SF1_IP").substitute(os.environ)
SF2_IP = Template("$SF2_IP").substitute(os.environ)
SF3_IP = Template("$SF3_IP").substitute(os.environ)
SF4_IP = Template("$SF4_IP").substitute(os.environ)
SF2_PROXY_IP = Template("$SF2_PROXY_IP").substitute(os.environ)
SF3_PROXY_IP = Template("$SF3_PROXY_IP").substitute(os.environ)
SF4_PROXY_IP = Template("$SF4_PROXY_IP").substitute(os.environ)
SFF2_IP = Template("$SFF2_IP").substitute(os.environ)
CLASSIFIER2_IP = Template("$CLASSIFIER2_IP").substitute(os.environ)
proxies = {
    "http": None,
    "https": None
}
SLEEP_DELAY = 2


def put(host, port, uri, data, debug=False):
    '''Perform a PUT rest operation, using the URL and data provided'''

    url = 'http://' + host + ":" + port + uri

    headers = {'Content-type': 'application/yang.data+json',
               'Accept': 'application/yang.data+json'}
    if debug:
        print "PUT %s" % url
        print json.dumps(data, indent=4, sort_keys=True)
    r = requests.put(url, proxies=proxies, data=json.dumps(data), headers=headers,
                     auth=HTTPBasicAuth(USERNAME, PASSWORD))
    if debug:
        print r.text
    r.raise_for_status()
    time.sleep(SLEEP_DELAY)


def post(host, port, uri, data, debug=False):
    '''Perform a POST rest operation, using the URL and data provided'''

    url = 'http://' + host + ":" + port + uri
    headers = {'Content-type': 'application/yang.data+json',
               'Accept': 'application/yang.data+json'}
    if debug:
        print "POST %s" % url
        print json.dumps(data, indent=4, sort_keys=True)
    r = requests.post(url, proxies=proxies, data=json.dumps(data), headers=headers,
                      auth=HTTPBasicAuth(USERNAME, PASSWORD))
    if debug:
        print r.text
    r.raise_for_status()
    time.sleep(SLEEP_DELAY)


def delete(host, port, uri, debug=False):
    '''Perform a DELETE rest operation, using the URL and data provided'''

    url = 'http://' + host + ":" + port + uri
    headers = {'Content-type': 'application/yang.data+json',
               'Accept': 'application/yang.data+json'}
    if debug:
        print "DELETE %s" % url
    r = requests.delete(url, proxies=proxies, headers=headers, auth=HTTPBasicAuth(USERNAME, PASSWORD))
    if debug:
        print r.text
    r.raise_for_status()
    time.sleep(SLEEP_DELAY)


def get_service_function_chains_uri():
    return "/restconf/config/service-function-chain:service-function-chains/"


def get_service_function_chains_data():
    return {
        "service-function-chains": {
            "service-function-chain": [
                {
                    "name": "SFC1",
                    "sfc-service-function": [
                        {
                            "name": "firewall-abstract2",
                            "type": "firewall2"
                        },
                        {
                            "name": "firewall-abstract3",
                            "type": "firewall3"
                        },
                        {
                            "name": "firewall-abstract4",
                            "type": "firewall4"
                        }

                    ]
                },
                {
                    "name": "SFC2",
                    "sfc-service-function": [
                        {
                            "name": "firewall-abstract2",
                            "type": "firewall2"
                        }
                    ]
                },
                {
                    "name": "SFC3",
                    "sfc-service-function": [
                        {
                            "name": "dpi-abstract1",
                            "type": "dpi"
                        },
                        {
                            "name": "firewall-abstract2",
                            "type": "firewall2"
                        },
                        {
                            "name": "firewall-abstract4",
                            "type": "firewall4"
                        }
                    ]
                }

            ]
        }
    }


def get_service_function_paths_uri():
    return "/restconf/config/service-function-path:service-function-paths/"


def get_service_function_paths_data():
    return {
        "service-function-paths": {
            "service-function-path": [
                {
                    "name": "SFP1",
                    "service-chain-name": "SFC1",
                    "starting-index": 255,
                    "symmetric": "true",
                    "context-metadata": "NSH1"
                },
                {
                    "name": "SFP2",
                    "service-chain-name": "SFC2",
                    "starting-index": 255,
                    "symmetric": "true",
                    "context-metadata": "NSH1"
                },
                {
                    "name": "SFP3",
                    "service-chain-name": "SFC3",
                    "starting-index": 255,
                    "symmetric": "true",
                    "context-metadata": "NSH1"
                }

            ]
        }
    }


def get_create_rendered_service_path_uri():
    return "/restconf/operations/rendered-service-path:create-rendered-path/"


def get_delete_rendered_service_path_uri():
    return "/restconf/operations/rendered-service-path:delete-rendered-path/"


def get_rendered_service_path_data():
    return {
        "input": {
            "name": "RSP1",
            "parent-service-function-path": "SFP1",
        }
    }


def get_rendered_service_path_data2():
    return {
        "input": {
            "name": "RSP2",
            "parent-service-function-path": "SFP2",
        }
    }


def get_rendered_service_path_data3():
    return {
        "input": {
            "name": "RSP3",
            "parent-service-function-path": "SFP3",
        }
    }


def get_rendered_service_path_data_for_delete():
    return {
        "input": {
            "name": "RSP1"
        }
    }


def get_rendered_service_path_data2_for_delete():
    return {
        "input": {
            "name": "RSP2"
        }
    }

def get_rendered_service_path_data3_for_delete():
    return {
        "input": {
            "name": "RSP3"
        }
    }

def get_service_function_acl_uri():
    return "/restconf/config/ietf-access-control-list:access-lists/"


def get_service_function_acl_data():
    return {
        "access-lists": {
            "acl": [
                {
                    "acl-name": "ACL1",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE11",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP1"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.2.0/25",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE12",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP1"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.2.0/25",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 0
                                    },
                                    "destination-port-range": {
                                        "lower-port": 80
                                    }
                                }
                            }
                        ]
                    }
                },
                {
                    "acl-name": "ACL2",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE21",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP1-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/25",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE22",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP1-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/25",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 80
                                    },
                                    "destination-port-range": {
                                        "lower-port": 0
                                    }
                                }
                            }
                        ]
                    }
                },
                {
                    "acl-name": "ACL3",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE31",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP2"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.2.129/32",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE32",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP2"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.2.129/32",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 0
                                    },
                                    "destination-port-range": {
                                        "lower-port": 80
                                    }
                                }
                            }
                        ]
                    }
                },
                {
                    "acl-name": "ACL4",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE41",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP2-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.129/32",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE42",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP2-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.129/32",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 80
                                    },
                                    "destination-port-range": {
                                        "lower-port": 0
                                    }
                                }
                            }
                        ]
                    }
                },
                {
                    "acl-name": "ACL5",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE51",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP3"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.3.100/32",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE52",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP3"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.2.0/24",
                                    "source-ipv4-network": "192.168.3.100/32",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 0
                                    },
                                    "destination-port-range": {
                                        "lower-port": 80
                                    }
                                }
                            }
                        ]
                    }
                },
                {
                    "acl-name": "ACL6",
                    "acl-type": "ietf-access-control-list:ipv4-acl",
                    "access-list-entries": {
                        "ace": [
                            {
                                "rule-name": "ACE61",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP3-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.3.100/32",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "1",
                                    "source-port-range": {
                                        "lower-port": "0"
                                    },
                                    "destination-port-range": {
                                        "lower-port": "0"
                                    }
                                }
                            },
                            {
                                "rule-name": "ACE62",
                                "actions": {
                                    "service-function-acl:rendered-service-path": "RSP3-Reverse"
                                },
                                "matches": {
                                    "destination-ipv4-network": "192.168.3.100/32",
                                    "source-ipv4-network": "192.168.2.0/24",
                                    "protocol": "6",
                                    "source-port-range": {
                                        "lower-port": 80
                                    },
                                    "destination-port-range": {
                                        "lower-port": 0
                                    }
                                }
                            }
                        ]
                    }
                }
            ]
        }
    }


def get_service_function_classifiers_uri():
    return "/restconf/config/service-function-classifier:service-function-classifiers/"


def get_service_function_classifiers_data():
    return {
        "service-function-classifiers": {
            "service-function-classifier": [
                {
                    "name": "Classifier1",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier1",
                            "interface": "veth-br"
                        }
                    ],
                    "acl": {
                        "name": "ACL1",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                },
                {
                    "name": "Classifier2",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier2",
                            "interface": "veth-br"
                        }
                    ],
                    "acl": {
                        "name": "ACL2",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                },
                {
                    "name": "Classifier1-2",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier1",
                            "interface": "veth-br2"
                        }
                    ],
                    "acl": {
                        "name": "ACL3",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                },
                {
                    "name": "Classifier2-2",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier2",
                            "interface": "veth-br"
                        }
                    ],
                    "acl": {
                        "name": "ACL4",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                },
                {
                    "name": "Classifier1-3",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier1",
                            "interface": "veth-br3"
                        }
                    ],
                    "acl": {
                        "name": "ACL5",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                },
                {
                    "name": "Classifier2-3",
                    "scl-service-function-forwarder": [
                        {
                            "name": "Classifier2",
                            "interface": "veth-br"
                        }
                    ],
                    "acl": {
                        "name": "ACL6",
                        "type": "ietf-access-control-list:ipv4-acl"
                    }
                }
            ]
        }
    }


if __name__ == "__main__":


    try:
        print "sending service function classifiers"
        delete(controller, DEFAULT_PORT, get_service_function_classifiers_uri(), True)
    except:
        pass

    try:
        print "delete rendered service paths"
        post(controller, DEFAULT_PORT, get_delete_rendered_service_path_uri(), get_rendered_service_path_data3_for_delete(), True)
    except:
        pass

    try:
        print "delete rendered service paths"
        post(controller, DEFAULT_PORT, get_delete_rendered_service_path_uri(), get_rendered_service_path_data2_for_delete(), True)
    except:
        pass

    try:
        print "delete rendered service paths"
        post(controller, DEFAULT_PORT, get_delete_rendered_service_path_uri(), get_rendered_service_path_data_for_delete(), True)
    except:
        pass

    try:
        print "delete service function acl"
        delete(controller, DEFAULT_PORT, get_service_function_acl_uri(), True)
    except:
        pass

    try:
        print "delete service function paths"
        delete(controller, DEFAULT_PORT, get_service_function_paths_uri(), True)
    except:
        pass

    try:
        print "delete service function chains"
        delete(controller, DEFAULT_PORT, get_service_function_chains_uri(), True)
    except:
        pass

    print "sending service function chains"
    put(controller, DEFAULT_PORT, get_service_function_chains_uri(), get_service_function_chains_data(), True)

    print "sending service function paths"
    put(controller, DEFAULT_PORT, get_service_function_paths_uri(), get_service_function_paths_data(), True)

    print "sending service function acl"
    put(controller, DEFAULT_PORT, get_service_function_acl_uri(), get_service_function_acl_data(), True)

    print "sending rendered service path"
    post(controller, DEFAULT_PORT, get_create_rendered_service_path_uri(), get_rendered_service_path_data(), True)

    print "sending rendered service path-sfc2"
    post(controller, DEFAULT_PORT, get_create_rendered_service_path_uri(), get_rendered_service_path_data2(), True)

    print "sending rendered service path-sfc3"
    post(controller, DEFAULT_PORT, get_create_rendered_service_path_uri(), get_rendered_service_path_data3(), True)

    print "sending service function classifiers"
    put(controller, DEFAULT_PORT, get_service_function_classifiers_uri(), get_service_function_classifiers_data(), True)
