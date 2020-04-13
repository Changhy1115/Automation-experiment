num=[0,0,5,100];
den=[0.0008,0.108,6,100];
%num=[0,0,6.3223,18,12.811];
%den=[1,6,11.3223,18,12.811];
%num=[0,0,0,250/3,5];
%den=[1/0.0288,6259/36,5045/36,253/3,5];
sys=tf(num,den);
t=0:0.0005:20;
[y,t]=step(sys,t);
r1=1;
while y(r1)<1.00001
  r1=r1+1;
end
rise_time=(r1-1)*0.0005;
[ymax,tp]=max(y);
peak_time=(tp-1)*0.0005;
max_overshoot=ymax-1;
s=20/0.0005;
while y(s)>0.98&y(s)<1.02
    s=s-1;
end
settle_time=(s-1)*0.0005;
