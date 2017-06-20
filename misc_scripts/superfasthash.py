'''
Functions:
getSeed(seedType, source, destination)

'''


def getSeed(seedType, source, destination):
    if seedType.upper() == "IP":
        # Get IP seed, we split the IP strings on the '.' character. [2] is the 3rd octet and [3] is the last(4th)
        # For ?.?.x.y the seed value is 256x + y
        # Set C and D to 0 as we do not need them for IP load balancing
        A = int(source.split('.')[3]) + (int(source.split('.')[2])*256)
        B = int(destination.split('.')[3]) + (int(destination.split('.')[2])*256)
        C = 0
        D = 0
    elif seedType.upper() == "MAC":
        # Similar to I we take the final two bytes, except we split on ":" to do so and take [4] and [5]
        # For ?:?:?:?:x:y the seed value is 256x + y
        # Set C and D to 0 as we do not need them for MAC load balancing
        A = int(source.split(':')[4] + source.split(':')[5], 16)
        B = int(destination.split(':')[4] + destination.split(':')[5], 16)
        C = 0
        D = 0
    elif seedType.upper() == "PORT":
        # A and B set as IP Load balancing dictates, we have to split off the port after the ':'
        # For C and D we split on ':' and take the second index [1]
        # We then concat the LS bytes with the MS bytes to reverse them for our seed.
        A = int(source.split('.')[3].split(':')[0]) + (int(source.split('.')[2])*256)
        B = int(destination.split('.')[3].split(':')[0]) + (int(destination.split('.')[2])*256)
        C = int('{0:032b}'.format(int(source.split(':')[1]))[16:32] + \
                '{0:032b}'.format(int(source.split(':')[1]))[0:16], 2)
        D = int('{0:032b}'.format(int(destination.split(':')[1]))[16:32] + \
                '{0:032b}'.format(int(destination.split(':')[1]))[0:16], 2)

    return A, B, C, D

# Test Cases and results for getSeed()
# print(getSeed("ip", "2.3.4.5", "10.10.92.167"))
# print(getSeed("port", "2.3.4.5:25523", "10.10.92.167:6007"))
# print(getSeed("mac", "02:aa:2b:31:ff:f4", "0a:1b:2d:3c:4e:5f"))
# (1029, 23719, 0, 0)
# (1029, 23719, 1672675328, 393674752)
# (65524, 20063, 0, 0)


# Below is not at all optimized as it was created slowly over the step by step alg
# We can make it faster by combining steps mathematically and removing the superfluous variable assignments
# As this should not actually affect a use of the tool it will likely never happen unless someone wants a project
def superfasthash(seedType, source, destination, numberOfInterfaces):
    A, B, C, D = getSeed(seedType, source, destination)
    val = int('{0:032b}'.format(B << 11)[-32:], 2)
    val ^= A
    valAShift = int('{0:032b}'.format(A << 16)[-32:], 2)
    val ^= valAShift
    val6 = int('11111111111{0:021b}'.format(val >> 11), 2)
    val7 = int('{0:032b}'.format(val6 + val)[-32:], 2)
    if seedType.upper() == "PORT":
        val8 = int('{0:032b}'.format(val7 + C)[-32:], 2)
        D = int('{0:032b}'.format(D << 11)[-32:], 2)
        val10 = D ^ val8
        val8 = int('{0:032b}'.format(val8 << 16)[-32:], 2)
        val12 = val8 ^val10
        val13 = val12 >> 11
        val14 = int('{0:032b}'.format(val13 + val12)[-32:], 2)
        val15 = int('{0:032b}'.format(val14 << 3)[-32:], 2)
        val16 = val14 ^ val15
    elif seedType.upper() == "MAC" or "IP":
        val15 = int('{0:032b}'.format(val7 << 3)[-32:], 2)
        val16 = val7 ^ val15
    val17 = val16 >> 5
    val18 = int('{0:032b}'.format(val16 + val17)[-32:], 2)
    val19 = int('{0:032b}'.format(val18 << 4), 2)
    val20 = val18 ^ val19
    val21 = int('11111111111111111{0:015b}'.format(val20 >> 17), 2)
    val22 = int('{0:032b}'.format(val20 + val21), 2)
    val23 = int('{0:032b}'.format(val22 << 25), 2)
    val24 = val23 ^ val22
    val25 = int('111111{0:026b}'.format(val24 >> 6), 2)
    val26 = int('{0:032b}'.format(val24 + val25), 2)
    return int(val26 % numberOfInterfaces)





# print(superfasthash("PORT", "10.10.137.171:21132", "10.10.69.103:10566", 4))
# Produces a value of 1 which is correct this test case is from the KB below
# https://kb.netapp.com/support/index?page=content&id=1014277&locale=en_US&access=s

