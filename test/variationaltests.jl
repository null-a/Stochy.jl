import Stochy: rewrite_address, rewrite_param_addresses

@test rewrite_address(list(1,5), list(), list()) == list(1,5)
@test rewrite_address(list(2,5), list(), list(1)) == list(1,2,5)
@test rewrite_address(list(1,5), list(1), list()) == list(5)
@test rewrite_address(list(1,5), list(1), list(2)) == list(2,5)
@test rewrite_address(list(1,2,4), list(1,2), list(3)) == list(3,4)
@test rewrite_address(list(1,4,5), list(1), list(2,3)) == list(2,3,4,5)

@test rewrite_param_addresses({list(3,1,0) => :param}, list(1,0), list(2)) == {list(3,2) => :param}
