@test_throws ErrorException Stochy.rand([NaN])
@test_throws ErrorException Stochy.rand([NaN, NaN])
