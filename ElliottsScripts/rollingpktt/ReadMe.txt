Intelligent Rolling Packet Traces

Summary:

This script is designed to start rolling packet traces for Clustered Data ONTAP, monitor the volumes, and start removing the oldest traces to stay under a certain threshold. (default is 80% capacity)

CentOS Preparation:

Login to the console as root
Make a local directory for each node in the cluster: mkdir /node1 /node2 /node3 …etc
Create a ssh publickey:
[root@cent7 ~]# ssh-keygen 
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): <==DON’T ENTER A PASSWORD
Enter same passphrase again: <==JUST PRESS RETURN
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
5b:a4:da:d8:87:17:0d:dd:68:b0:01:b1:77:69:d2:29 root@cent7
The key's randomart image is:
+--[ RSA 2048]----+
|        ooo      |
|         . * =   |
|        . E X .  |
|         + O     |
|        S o .    |
|       = + .     |
|      o = o      |
|         o       |
|                 |
+————————+
Copy the publickey to your clipboard
[root@cent7 ~]# cat ~/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4TdpyIeWiLw4GVC/3JwNbpoVwBsFQiDm9bQlbpOx3p0PVLJ4/jJ5vT7MD7w6VjKwcvSNQd3uQVDGchZvIt0Ww7JD4/QYzIoSvm0WOoBBX+uz93I5Yp+BeUP9Ez3mVfprqB5fBE5sUlsvXTK2JWtPMidn8NmXpYCS0OX/lWRrzRr2n55coLVKM5wwkw2Vu0NCQZJJ9SBvTuSWpJKFjQVVL7zC6Fscda5Gi44wMLVuqI//0IYn3KOvEH5Dhrw7R3fWKjLwPoeX645IblfKueCICtjVO9KXRtWJCex+g6BzGe3ze8avia+bnBO0fbKlqFU/gXxGTyqX3l4/PASwkJDZd root@cent7
SSH into the cluster shell
Create the passwordless publickey login for the admin:
::> security login create -user-or-group-name admin -application ssh -authmethod publickey
::> security login publickey create -username admin -index 0 -publickey “<paste key here>”
::> exit
SSH back into the cluster as admin, accept the key, and make sure it doesn’t require a password

At this point we need to prepare the cluster for the traces.  There are a few very important requirements to keep in mind:

There must be a volume that MUST BE NAMED ‘pktt’ located on each node in the cluster if this is a multi-node trace.
You can not have duplicate volume names in any SVM, so if this is a four-node trace, you must have four SVMs, each with a volume named ‘pktt’, and each volume on a different node.
You must have NFS access to each SVM, preferably with a LIF that is located on the same node as the ‘pktt’ volume for that SVM.
The CentOS client must have root access to the volume.

With that in mind, the following steps show you had to prepare CDOT for a two-node trace.  We will assume that we must create everything from scratch, but if you have aggregates, SVMs, or data LIFs that already exist and can be used, that is fine too.  The one exception is the volumes.  The volumes MUST BE CREATED SO THEY HAVE THE SAME NAME!  Run the following commands from the cluster shell:

::> aggr create -aggregate node1_aggr -diskcount 5 -node <node1>
::> vserver create -vserver pktt_node1 -rootvolume pktt_node1 -aggregate node1_aggr -rootvolume-security-style unix
::> vserver nfs create -vserver pktt_node1
::> vserver export-policy create -vserver pktt_node1 -policyname pktt_node1
::> vserver export-policy rule create -vserver pktt_node1 -policyname pktt_node1 -clientmatch 0.0.0.0/0 -rorule any -rwrule any -superuser any
::> vol create -vserver pktt_node1 -volume pktt -aggregate node1_aggr -size 500G -security-style unix
::> mount -vserver pktt_node1 -volume pktt -junction-path /pktt
::> vol modify -vserver pktt_node1 -volume * -policy pktt_node1
::> net int create -vserver pktt_node1 -lif pktt_node1 -role data -data-protocol nfs -home-node <node1> -home-port <port_name> -address <ip_address> -netmask <netmask>

Repeat the above steps for each node in the cluster if this is a multi-node trace.  If you are tracing just a single node, you are ready to finish the client side configuration

Log back in as root to the CentOS box
mount -t nfs -o vers=3 10.1.2.3:/pktt /node1 <== Repeat this step for each pktt volume
mount | grep -i pktt <== If the output is blank, troubleshoot why it didn’t mount
Open up the script in your console-based text editor of choice, and edit the variables at the top of the script.
Edit the variables to suit your environment
Start the script

