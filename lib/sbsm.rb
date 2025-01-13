#--
# Copyright 2016 Niklaus Giger <ngiger@ywesee.com>
#++
#
# *SBSM:* Application framework for state based session management.
#
# We document here a few aspects of SBSM. As it is written over 10 years
# after the creation of one of the few users, who never had the chance to
# discuss with the creator of this piece of software, errors/obmission
# are found quite often.
#
# The behaviour of SBSM can be extended or overriden in many ways.
# Often in derived classes you simply define a few constants, these
# extension points can be spotted by searching for occurrences of
# -self::class::- in the implementation of SBSM.
#
# * *lookandfeel*: offers a simple way to customize views, constants
#   for different languages
#
# * *viralstate*: Used in bbmb and sandoz.com
#
# * *session*: Used in bbmb and sandoz.com
#
# * *request*: Used in bbmb and sandoz.com
#
# * *transhandler*: Responsible for converting an URI into a hash of
#   option values, e.g. /de/gcc/fachinfo/reg/58980
#
module SBSM
end
