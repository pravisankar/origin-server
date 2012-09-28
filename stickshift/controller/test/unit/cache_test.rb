require 'test_helper'

class CacheTest < ActiveSupport::TestCase
  include CacheHelper

  def setup
    super
    @key = "foo"
    Rails.cache.clear
    Rails.configuration.action_controller.perform_caching = true
  end

  test "no block given" do
    assert_equal nil, Rails.cache.read(@key)
    val = get_cached(@key)
    assert_equal nil, val
  end

  test "cache miss" do
    assert_equal nil, Rails.cache.read(@key)
    val = get_cached(@key) {
      "apple"
    }
    assert_equal "apple", val
    assert_equal "apple", Rails.cache.read(@key)
  end

  test "cache hit" do
    assert_equal nil, Rails.cache.read(@key)
    Rails.cache.write(@key, "orange")

    val = get_cached(@key) {
      "apple"
    }

    assert_equal "orange", val
    assert_equal "orange", Rails.cache.read(@key)
  end

  test "cache expiry" do
    assert_equal nil, Rails.cache.read(@key)

    val = get_cached(@key, :expires_in => 1.seconds) {
      "apple"
    }

    assert_equal "apple", val
    assert_equal "apple", Rails.cache.read(@key)

    sleep 1

    assert_equal nil, Rails.cache.read(@key)

    val = get_cached(@key) {
      "orange"
    }

    assert_equal "orange", val
    assert_equal "orange", Rails.cache.read(@key)
  end
end
