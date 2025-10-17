"""

THE CASES TO TEST IN MARK PAYMENT : 

- THE MAIN PARAMETERS : 
    - attended non paid classes 
    - number of classes to mark as paid
- THE CASES :
    1. attended non paid classes == 0 number of classes to mark as paid = 2  : 
        - checks : 
            - the attend and non paid classes didn't descrease 
            - we create 2 classes to mark them as paid 
            - the paid amount increases and the unpaid amount doesn't decrease

    2. 0 < attended non paid classes < 4 and number of classes to mark as paid < attended non paid classes :
        - checks :
            - the attended non paid classes decrease by the number of classes marked as paid
            - we mark as paid thes oldest {number of classes to mark as paid} attended non paid classes
            - we will not create new classes 
            - the paid amount increases and the unpaid amount doesn't decrease

    3. 0 < attended non paid classes < 4 and  number of classes to mark as paid > attended non paid classes :
        - checks : 
            - the attended non paid classes become 0
            - we will use all the attended non paid classes to mark as paid
            - we will create new classes to mark as paid for the remaining number of classes to mark as paid
            - the paid amount increases and the unpaid amount doesn't decrease

    4. attended non paid classes = 7 and the number of classes to mark as paid = 2 
        - checks : 
            - we mark as paid thes oldest 2 attended non paid classes
            - decrease the attended non paid classes by  2 
            - decrease the unpaid amount by the price of 2 classes
            - increase the paid amount by the price of 2 classes
            - don't touch the rest of the attended and non paid classes 

    5. attended non paid classes = 7 and the number of classes to mark as paid = 4 
            - checks : 
                - we mark as paid the oldest 4 attended non paid classes
                - decrease the attended non paid classes by 4
                - reset the unpaid amount to 0 
                - increase the paid amount by the price of 4 classes
                - for the rest of attended and non paid classes mark them as paid not due

    6. attended non paid classes = 7 and the number of classes to mark as paid = 10
            - checks : 
                - we mark as paid all of the attended classes 
                - set the attended non paid classes = 0
                - create 3 new classes and marked them as paid
                - reset the unpaid amount to 0
                - increase the paid amount by the price of 10 classes
    


"""