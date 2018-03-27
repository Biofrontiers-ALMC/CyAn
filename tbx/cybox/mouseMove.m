function mouseMove (object, eventdata)
C = get (gca, 'CurrentPoint');
title(gca, ['(X,Y,I) = (', num2str(C(1,1)), ', ',num2str(C(1,2)), ')']);