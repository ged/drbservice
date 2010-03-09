# Goal: set up an SSL-enabled DRb service without having to specify the nasty bits yourself.

Feature: A basic DRb service
	In order to create a new basic service
	As a programmer
	I want to be able to just define the service object
		And have it wrapped in authentication and SSL

	Scenario: 
	    Given a basic service with a guarded "testme" method that returns "success"
	    When I 
	    Then outcome
	
	
	


